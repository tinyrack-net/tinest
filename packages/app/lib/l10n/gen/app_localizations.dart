import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  /// Dismisses a dialog without applying it.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Commits an edited form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Save button label while the write is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// Confirms a creation dialog.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// Create button label while the write is in flight.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get commonCreating;

  /// Acknowledges an informational dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonConfirm;

  /// Removes a stored record.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Runs a failed load again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Search field placeholder shared by Select controls.
  ///
  /// In en, this message translates to:
  /// **'Search options'**
  String get selectSearchPlaceholder;

  /// Empty result shown by searchable Select controls.
  ///
  /// In en, this message translates to:
  /// **'No matching options.'**
  String get selectNoResults;

  /// Closes a sheet or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Copies content to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Halts a running operation.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// Text field label for a human-readable name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// Text field label for a record type.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get commonKind;

  /// Text field label for a free-form description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// Status shown while work is in progress.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get commonRunning;

  /// Status shown when work finished successfully.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Opens a fuller view of a summary.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// Confirmation shown after a successful write.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get commonSaved;

  /// Confirmation shown after a successful removal.
  ///
  /// In en, this message translates to:
  /// **'Deleted.'**
  String get commonDeleted;

  /// Confirmation shown after copying a value the screen does not otherwise change to show.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard.'**
  String get commonCopied;

  /// Fallback title for an action that failed without a more specific message.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get commonActionFailed;

  /// Accessible name of the region that announces the result of an action.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get toastRegionLabel;

  /// Title of the settings shell.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Accessible status for a settings skeleton while data is loading.
  ///
  /// In en, this message translates to:
  /// **'Loading settings'**
  String get settingsLoading;

  /// Non-blocking error shown when refreshing already visible settings fails.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh settings: {error}'**
  String settingsRefreshFailed(String error);

  /// Settings sidebar heading over the app-wide categories.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// Settings sidebar heading over the categories owned by one daemon.
  ///
  /// In en, this message translates to:
  /// **'Daemon'**
  String get settingsSectionDaemon;

  /// Label of the sidebar picker choosing which daemon to edit.
  ///
  /// In en, this message translates to:
  /// **'Daemon'**
  String get settingsDaemonSelectLabel;

  /// Placeholder in the daemon picker when no daemon is configured.
  ///
  /// In en, this message translates to:
  /// **'No daemons'**
  String get settingsDaemonSelectEmpty;

  /// Shown when the selected daemon cannot serve its settings.
  ///
  /// In en, this message translates to:
  /// **'{label} is not connected.'**
  String settingsDaemonOffline(String label);

  /// Settings sidebar entry for app-wide preferences.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsCategoryGeneral;

  /// Settings sidebar entry for per-project hooks.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get settingsCategoryProjects;

  /// Settings sidebar entry for agent definitions.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get settingsCategoryAgent;

  /// Settings sidebar entry for provider connections.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsCategoryProvider;

  /// Settings sidebar entry for the daemon default model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsCategoryModel;

  /// Settings sidebar entry for daemon permission defaults.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsCategoryPermission;

  /// Settings sidebar entry for daemon connections.
  ///
  /// In en, this message translates to:
  /// **'Daemons'**
  String get settingsCategoryDaemon;

  /// Settings sidebar entry for developer maintenance actions.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsCategoryAdvanced;

  /// Title of the full reset row.
  ///
  /// In en, this message translates to:
  /// **'Reset all data'**
  String get advancedResetTitle;

  /// Scope of a reset on a surface that owns an embedded daemon.
  ///
  /// In en, this message translates to:
  /// **'Deletes the embedded daemon\'s database, credentials, MCP and agent configuration, skills, and attachments, and clears every app setting and stored remote daemon token. Git checkouts under the worktrees folder stay on disk.'**
  String get advancedResetDescription;

  /// Scope of a reset on a surface without an embedded daemon.
  ///
  /// In en, this message translates to:
  /// **'Clears every app setting and stored remote daemon token on this device. Remote daemons keep their own data.'**
  String get advancedResetDescriptionAppOnly;

  /// Label of the reset button while a reset runs.
  ///
  /// In en, this message translates to:
  /// **'Resetting…'**
  String get advancedResetRunning;

  /// Title of the full reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset all data?'**
  String get advancedResetConfirmTitle;

  /// Body of the full reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Every session, workspace registration, provider connection, agent, skill, and MCP server on the embedded daemon is deleted, together with every app setting and remote daemon profile and token. The daemon returns to its default port. Git checkouts stay on disk but have to be added again. This cannot be undone.'**
  String get advancedResetConfirmBody;

  /// Confirm action of the full reset dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get advancedResetConfirmAccept;

  /// Reported after a factory reset finishes and the app returns to the workspace.
  ///
  /// In en, this message translates to:
  /// **'Reset to factory defaults.'**
  String get advancedResetDone;

  /// Title of the alert shown when a reset fails.
  ///
  /// In en, this message translates to:
  /// **'Reset failed'**
  String get advancedResetFailedTitle;

  /// Reset failure caused by a daemon owning the data directory.
  ///
  /// In en, this message translates to:
  /// **'Another {appDisplayName} daemon is using the data directory. Quit it and try again. Nothing was deleted.'**
  String advancedResetFailedDaemonRunning(String appDisplayName);

  /// Reset failure reported by the operating system.
  ///
  /// In en, this message translates to:
  /// **'Some daemon files could not be deleted: {error}'**
  String advancedResetFailedFilesystem(String error);

  /// Reset failure that leaves device-local settings behind.
  ///
  /// In en, this message translates to:
  /// **'Daemon data was removed but the app settings could not be cleared. Restart {appDisplayName}.'**
  String advancedResetFailedIncomplete(String appDisplayName);

  /// Shown when a host-scoped settings page has no online daemon.
  ///
  /// In en, this message translates to:
  /// **'Connect an online daemon first.'**
  String get settingsRequiresOnlineDaemon;

  /// Dropdown label for the app theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get generalAppearanceLabel;

  /// Theme option that follows the operating system brightness.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get generalAppearanceSystem;

  /// Theme option that always paints the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get generalAppearanceLight;

  /// Theme option that always paints the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get generalAppearanceDark;

  /// Dropdown label for the app UI language.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get generalLanguageLabel;

  /// Language option that follows the operating system locale.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get generalLanguageSystem;

  /// Heading of the startup card on the General settings page.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get generalStartupSection;

  /// Switch label for launching the app when the user logs in.
  ///
  /// In en, this message translates to:
  /// **'Start at login'**
  String get generalStartupAtBootLabel;

  /// Switch label for starting hidden in the tray at login.
  ///
  /// In en, this message translates to:
  /// **'Start minimized'**
  String get generalStartupMinimizedLabel;

  /// Reported when the chosen theme could not be stored.
  ///
  /// In en, this message translates to:
  /// **'Could not change the appearance.'**
  String get generalAppearanceFailed;

  /// Reported when the chosen language could not be stored.
  ///
  /// In en, this message translates to:
  /// **'Could not change the language.'**
  String get generalLanguageFailed;

  /// Reported when a login-item preference could not be applied.
  ///
  /// In en, this message translates to:
  /// **'Could not change the startup setting.'**
  String get generalStartupFailed;

  /// Explains that the window close button no longer quits the app.
  ///
  /// In en, this message translates to:
  /// **'Closing the window keeps {appDisplayName} running in the tray.'**
  String generalStartupCloseNotice(String appDisplayName);

  /// Hover text of the tray icon.
  ///
  /// In en, this message translates to:
  /// **'{appDisplayName}'**
  String trayTooltip(String appDisplayName);

  /// Tray menu row that reveals the hidden main window.
  ///
  /// In en, this message translates to:
  /// **'Show window'**
  String get trayShowWindow;

  /// Tray menu row that hides the main window into the tray.
  ///
  /// In en, this message translates to:
  /// **'Hide window'**
  String get trayHideWindow;

  /// Tray menu row that opens the General settings page.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get trayOpenSettings;

  /// Tray menu row that stops the embedded daemon and exits the app.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// File menu in the custom desktop title bar.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get desktopMenuFile;

  /// View menu in the custom desktop title bar.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get desktopMenuView;

  /// Help menu in the custom desktop title bar.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get desktopMenuHelp;

  /// Opens application name and version information.
  ///
  /// In en, this message translates to:
  /// **'About {appDisplayName}'**
  String desktopMenuAbout(String appDisplayName);

  /// Tooltip for the custom window minimize button.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get desktopWindowMinimize;

  /// Tooltip for the custom window maximize button.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get desktopWindowMaximize;

  /// Tooltip for restoring a maximized window.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get desktopWindowRestore;

  /// Tooltip for hiding the resident app window to the tray.
  ///
  /// In en, this message translates to:
  /// **'Close to tray'**
  String get desktopWindowClose;

  /// Title of the workspace shell.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspacesTitle;

  /// Tooltip that reveals the collapsed workspace sidebar.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar'**
  String get workspaceSidebarExpand;

  /// Tooltip that collapses the workspace sidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar'**
  String get workspaceSidebarCollapse;

  /// Tooltip that starts an AI session in the open checkout.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get workspaceNewSession;

  /// Session tab title used when a prompt carries no readable title text.
  ///
  /// In en, this message translates to:
  /// **'Coding session'**
  String get sessionDefaultTitle;

  /// No description provided for @workspaceNewTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get workspaceNewTab;

  /// No description provided for @workspaceNewTerminal.
  ///
  /// In en, this message translates to:
  /// **'New terminal'**
  String get workspaceNewTerminal;

  /// Title of a newly created terminal tab, numbered within its worktree.
  ///
  /// In en, this message translates to:
  /// **'Terminal {number}'**
  String terminalTabTitle(int number);

  /// Announced once for the workspace pane skeleton shown while sessions and terminals load.
  ///
  /// In en, this message translates to:
  /// **'Loading workspace'**
  String get workspaceLoading;

  /// Announced once for the sidebar tree skeleton shown while daemon catalogs load.
  ///
  /// In en, this message translates to:
  /// **'Loading workspaces'**
  String get workspaceCatalogLoading;

  /// Non-blocking status shown while a previously loaded daemon catalog refreshes.
  ///
  /// In en, this message translates to:
  /// **'Refreshing workspaces…'**
  String get workspaceCatalogRefreshing;

  /// Inline error title when a daemon workspace catalog cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load workspaces'**
  String get workspaceCatalogFailed;

  /// Accessible label for the new-workspace branch skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading branches'**
  String get workspaceBranchesLoading;

  /// Inline error title when Git branch discovery fails.
  ///
  /// In en, this message translates to:
  /// **'Could not load branches'**
  String get workspaceBranchesFailed;

  /// Progress label while Git repository metadata is discovered during registration.
  ///
  /// In en, this message translates to:
  /// **'Adding project…'**
  String get workspaceRegisteringProject;

  /// Progress label while Git inspects archive safety.
  ///
  /// In en, this message translates to:
  /// **'Checking worktree…'**
  String get workspaceArchiveChecking;

  /// Progress label while the daemon checks out a new worktree and runs its hooks.
  ///
  /// In en, this message translates to:
  /// **'Creating worktree…'**
  String get workspaceCreatingWorktree;

  /// Progress label while the daemon creates the session for a submitted prompt.
  ///
  /// In en, this message translates to:
  /// **'Starting session…'**
  String get workspaceStartingSession;

  /// Label of a placeholder terminal tab while the daemon creates its shell.
  ///
  /// In en, this message translates to:
  /// **'Starting terminal'**
  String get workspaceTerminalStarting;

  /// Error shown after a placeholder terminal tab is rolled back.
  ///
  /// In en, this message translates to:
  /// **'Could not start terminal: {error}'**
  String workspaceTerminalStartFailed(String error);

  /// No description provided for @terminalCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminate terminal?'**
  String get terminalCloseTitle;

  /// No description provided for @terminalCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Closing this tab terminates its shell and child processes.'**
  String get terminalCloseConfirm;

  /// No description provided for @terminalTerminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get terminalTerminate;

  /// No description provided for @terminalConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Terminal connection failed'**
  String get terminalConnectionFailed;

  /// Overlay label shown while a terminal pane attaches to its daemon shell.
  ///
  /// In en, this message translates to:
  /// **'Connecting to terminal'**
  String get terminalConnecting;

  /// Announced once for the chat timeline skeleton shown while session history loads.
  ///
  /// In en, this message translates to:
  /// **'Loading conversation'**
  String get conversationLoading;

  /// Row shown above the oldest loaded message while an earlier page of chat history is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading earlier messages'**
  String get conversationLoadingOlder;

  /// Row shown above the oldest loaded message when fetching an earlier page of chat history failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load earlier messages'**
  String get conversationLoadOlderFailed;

  /// Action beside the failed-history row that asks for the same earlier page again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get conversationLoadOlderRetry;

  /// Announced once for the row skeletons shown while the first directory listing loads.
  ///
  /// In en, this message translates to:
  /// **'Loading directories'**
  String get directoryBrowserLoading;

  /// No description provided for @terminalCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create terminal'**
  String get terminalCreationFailed;

  /// No description provided for @terminalWorktreeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This worktree is no longer available. Choose another worktree.'**
  String get terminalWorktreeUnavailable;

  /// No description provided for @terminalShellStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The configured terminal shell couldn\'t be started. Check terminal settings and try again.'**
  String get terminalShellStartFailed;

  /// No description provided for @terminalMenuCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get terminalMenuCopy;

  /// No description provided for @terminalMenuPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalMenuPaste;

  /// No description provided for @terminalMenuSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get terminalMenuSelectAll;

  /// No description provided for @terminalMenuClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get terminalMenuClearSelection;

  /// No description provided for @terminalMenuClearScreen.
  ///
  /// In en, this message translates to:
  /// **'Clear screen'**
  String get terminalMenuClearScreen;

  /// Section heading for the per-project worktree hooks.
  ///
  /// In en, this message translates to:
  /// **'Worktree lifecycle hooks'**
  String get projectSettingsHookHeading;

  /// No description provided for @projectSettingsShellHeading.
  ///
  /// In en, this message translates to:
  /// **'Project terminal shell'**
  String get projectSettingsShellHeading;

  /// No description provided for @projectSettingsShellHelp.
  ///
  /// In en, this message translates to:
  /// **'Overrides the daemon host shell for terminals opened in this project. Leave the executable empty to inherit the host default.'**
  String get projectSettingsShellHelp;

  /// No description provided for @projectSettingsShellExecutable.
  ///
  /// In en, this message translates to:
  /// **'Shell executable'**
  String get projectSettingsShellExecutable;

  /// No description provided for @projectSettingsShellArguments.
  ///
  /// In en, this message translates to:
  /// **'Shell arguments (one per line)'**
  String get projectSettingsShellArguments;

  /// No description provided for @projectSettingsHostShellHeading.
  ///
  /// In en, this message translates to:
  /// **'Daemon host default shell'**
  String get projectSettingsHostShellHeading;

  /// No description provided for @projectSettingsHostShellHelp.
  ///
  /// In en, this message translates to:
  /// **'Used by every project on this daemon host unless the project overrides it. Leave the executable empty to use the operating system default.'**
  String get projectSettingsHostShellHelp;

  /// Tooltip that lists every session of the open checkout.
  ///
  /// In en, this message translates to:
  /// **'All sessions'**
  String get workspaceAllSessions;

  /// Splits a workspace pane with a new pane on the right.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get workspaceSplitRight;

  /// Splits a workspace pane with a new pane below.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get workspaceSplitDown;

  /// Accessible label for a draggable pane separator.
  ///
  /// In en, this message translates to:
  /// **'Resize panes'**
  String get workspaceResizePanes;

  /// Moves the active tab to another pane without dragging.
  ///
  /// In en, this message translates to:
  /// **'Move active tab to pane'**
  String get workspaceMoveTabToPane;

  /// Tooltip that closes one session tab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get workspaceCloseTab;

  /// Opens the new-workspace composer.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get workspaceNewWorkspace;

  /// Tooltip of the per-worktree overflow menu.
  ///
  /// In en, this message translates to:
  /// **'Worktree menu'**
  String get workspaceWorktreeMenu;

  /// Accessible label for a registered project's action menu.
  ///
  /// In en, this message translates to:
  /// **'Project menu'**
  String get workspaceProjectMenu;

  /// Removes a project registration without deleting its files.
  ///
  /// In en, this message translates to:
  /// **'Remove project'**
  String get workspaceUnregister;

  /// Confirmation title for removing a project registration.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String workspaceUnregisterTitle(String name);

  /// Explains that unregistering a project is non-destructive.
  ///
  /// In en, this message translates to:
  /// **'The project disappears from {appName}, but its repository and files stay on disk.'**
  String workspaceUnregisterBody(String appName);

  /// Menu entry and button that archives a checkout.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get workspaceArchive;

  /// Dialog title when running sessions block an archive.
  ///
  /// In en, this message translates to:
  /// **'Cannot archive'**
  String get workspaceArchiveBlockedTitle;

  /// Explains that sessions must be stopped before archiving.
  ///
  /// In en, this message translates to:
  /// **'Stop the {count} running session(s) first.'**
  String workspaceArchiveBlockedBody(int count);

  /// Confirmation title for archiving one checkout.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String workspaceArchiveTitle(String name);

  /// Archive warning fragment for a dirty checkout.
  ///
  /// In en, this message translates to:
  /// **'It has uncommitted changes.\n'**
  String get workspaceArchiveDirty;

  /// Archive warning fragment for unpushed commits.
  ///
  /// In en, this message translates to:
  /// **'It has {count} unpushed commit(s).\n'**
  String workspaceArchiveUnpushed(int count);

  /// Archive effect for a removable checkout.
  ///
  /// In en, this message translates to:
  /// **'The checkout directory will be removed.'**
  String get workspaceArchiveRemovesDirectory;

  /// Archive confirmation label when the checkout has unsaved work.
  ///
  /// In en, this message translates to:
  /// **'Confirm the risks and archive'**
  String get workspaceArchiveRisky;

  /// Empty state of the workspace sidebar.
  ///
  /// In en, this message translates to:
  /// **'No daemons are configured.'**
  String get workspaceNoDaemons;

  /// Sidebar empty state when every configured daemon is offline.
  ///
  /// In en, this message translates to:
  /// **'No daemon is connected.'**
  String get workspaceNoConnectedDaemons;

  /// Sidebar empty state when connected daemons have no workspace.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet.'**
  String get workspaceNoWorkspaces;

  /// Sidebar section listing sessions that belong to no project.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get workspaceNoProjectSessions;

  /// Composer choice that starts a session in the user home.
  ///
  /// In en, this message translates to:
  /// **'No project (home folder)'**
  String get workspaceNoProjectOption;

  /// Label of the new-workspace project chip before a project is chosen.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get workspaceProjectChip;

  /// Tooltip of the new-workspace project chip.
  ///
  /// In en, this message translates to:
  /// **'Select a project'**
  String get workspaceProjectChipTooltip;

  /// Menu entry that registers another project from the new-workspace chip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get workspaceProjectAdd;

  /// New-workspace worktree chip and menu entry that creates a fresh checkout.
  ///
  /// In en, this message translates to:
  /// **'New worktree'**
  String get workspaceWorktreeNew;

  /// New-workspace worktree chip and menu entry that runs the session in the registered repository folder itself.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get workspaceWorktreeLocal;

  /// Tooltip of the new-workspace worktree chip.
  ///
  /// In en, this message translates to:
  /// **'Select a worktree'**
  String get workspaceWorktreeChipTooltip;

  /// Label of the new-workspace base branch chip before a branch is chosen.
  ///
  /// In en, this message translates to:
  /// **'Base branch'**
  String get workspaceBaseBranchChip;

  /// Tooltip of the new-workspace base branch chip.
  ///
  /// In en, this message translates to:
  /// **'Select a base branch'**
  String get workspaceBaseBranchChipTooltip;

  /// Composer hint when no project is registered.
  ///
  /// In en, this message translates to:
  /// **'Add a project first.'**
  String get workspaceAddProjectFirst;

  /// Composer hint when no project is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a project.'**
  String get workspaceSelectProject;

  /// Composer hint when a directory project has no checkout.
  ///
  /// In en, this message translates to:
  /// **'No project checkout was found.'**
  String get workspaceCheckoutMissing;

  /// Composer error when no daemon is connected.
  ///
  /// In en, this message translates to:
  /// **'A daemon connection is required.'**
  String get workspaceDaemonRequired;

  /// Button that opens daemon settings from the empty sidebar.
  ///
  /// In en, this message translates to:
  /// **'Daemon settings'**
  String get workspaceOpenDaemonSettings;

  /// Title of the failure alert on the new workspace screen.
  ///
  /// In en, this message translates to:
  /// **'The session could not be started'**
  String get workspaceStartFailedTitle;

  /// Composer hint when no provider model is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a provider and model first.'**
  String get composerSelectProviderModel;

  /// Daemon rejected a branch name that is already taken.
  ///
  /// In en, this message translates to:
  /// **'A branch with that name already exists. Choose another name.'**
  String get errorBranchAlreadyExists;

  /// Daemon rejected a worktree path that is already occupied.
  ///
  /// In en, this message translates to:
  /// **'Another checkout already uses that folder.'**
  String get errorWorktreePathInUse;

  /// Daemon rejected a branch name that is not a valid Git ref.
  ///
  /// In en, this message translates to:
  /// **'That name can\'t be used as a Git branch.'**
  String get errorInvalidBranchName;

  /// A Git invocation exited non-zero.
  ///
  /// In en, this message translates to:
  /// **'A Git command failed. The details below are Git\'s own output.'**
  String get errorGitCommandFailed;

  /// Daemon could not find the referenced workspace.
  ///
  /// In en, this message translates to:
  /// **'That project is no longer registered with the daemon.'**
  String get errorWorkspaceNotFound;

  /// Operation requires a Git repository.
  ///
  /// In en, this message translates to:
  /// **'That project is not a Git repository, so it has no worktrees.'**
  String get errorWorkspaceNotGit;

  /// Home workspace cannot be registered or removed.
  ///
  /// In en, this message translates to:
  /// **'The daemon owns that folder and manages it itself.'**
  String get errorWorkspaceProtected;

  /// Daemon could not find the referenced worktree.
  ///
  /// In en, this message translates to:
  /// **'That checkout is no longer registered with the daemon.'**
  String get errorWorktreeNotFound;

  /// Archive refused because of running sessions or local changes.
  ///
  /// In en, this message translates to:
  /// **'This checkout can\'t be archived right now.'**
  String get errorWorktreeArchiveBlocked;

  /// Referenced agent definition was deleted.
  ///
  /// In en, this message translates to:
  /// **'That agent no longer exists. Choose another agent.'**
  String get errorAgentDefinitionNotFound;

  /// Referenced agent definition exists but cannot start a session.
  ///
  /// In en, this message translates to:
  /// **'That agent can\'t start a session. Choose another agent.'**
  String get errorAgentDefinitionUnusable;

  /// The daemon rejected a request as unknown or malformed, which means version skew.
  ///
  /// In en, this message translates to:
  /// **'This app and the daemon speak different protocol versions. Update both to the same release.'**
  String get errorProtocolMismatch;

  /// A project settings file failed to parse.
  ///
  /// In en, this message translates to:
  /// **'The project\'s .tinest/config.json could not be read. Fix the file and try again.'**
  String get errorInvalidProjectSettings;

  /// A request exceeded the client deadline.
  ///
  /// In en, this message translates to:
  /// **'The daemon didn\'t respond in time. Try again.'**
  String get errorRequestTimeout;

  /// Unexpected daemon-side failure with a trace id in the details.
  ///
  /// In en, this message translates to:
  /// **'The daemon hit an unexpected problem. Copy the details below when reporting it.'**
  String get errorInternalDaemon;

  /// A plugin UI render or action request was safely rejected by the host.
  ///
  /// In en, this message translates to:
  /// **'The plugin interface request was rejected.'**
  String get errorPluginUiRejected;

  /// The plugin has no revision this Agent has activated yet.
  ///
  /// In en, this message translates to:
  /// **'This agent has not activated the plugin yet. Send a message to start it.'**
  String get errorPluginRevisionUnavailable;

  /// A session setting such as the mode or the model was changed while a turn was still streaming.
  ///
  /// In en, this message translates to:
  /// **'This session is running a turn. Wait for it to finish or stop it, then change the setting.'**
  String get errorSessionTurnActive;

  /// Fallback shown when a session setting change fails for a reason the daemon did not name.
  ///
  /// In en, this message translates to:
  /// **'The session setting could not be changed.'**
  String get errorSessionSettingFailed;

  /// Daemon runtime status.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get hostStatusOnline;

  /// Daemon runtime status.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get hostStatusConnecting;

  /// Daemon runtime status.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get hostStatusReconnecting;

  /// Daemon runtime status.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get hostStatusOffline;

  /// Daemon runtime status.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get hostStatusError;

  /// Daemon runtime status when two profiles reach the same daemon.
  ///
  /// In en, this message translates to:
  /// **'Duplicate daemon'**
  String get hostStatusConflict;

  /// Daemon runtime status when auto-connect is disabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect off'**
  String get hostStatusIdle;

  /// Daemon status before a runtime exists.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get hostStatusPending;

  /// Display name of the app-owned desktop daemon.
  ///
  /// In en, this message translates to:
  /// **'Embedded daemon'**
  String get embeddedDaemonName;

  /// Validation error when a remote profile has no token.
  ///
  /// In en, this message translates to:
  /// **'Enter a bearer token.'**
  String get hostErrorMissingToken;

  /// Connection failure when the stored token is missing.
  ///
  /// In en, this message translates to:
  /// **'No bearer token is stored.'**
  String get hostErrorNoToken;

  /// Connection failure when two profiles reach the same daemon.
  ///
  /// In en, this message translates to:
  /// **'That daemon is already registered.'**
  String get hostErrorDuplicate;

  /// Connection failure when the daemon returns 401.
  ///
  /// In en, this message translates to:
  /// **'The daemon rejected the bearer token.'**
  String get hostErrorUnauthorized;

  /// Embedded daemon startup failure when its listener port is occupied.
  ///
  /// In en, this message translates to:
  /// **'The selected port is already in use.'**
  String get hostErrorEmbeddedPortInUse;

  /// Embedded daemon startup failure when another process already holds the daemon home.
  ///
  /// In en, this message translates to:
  /// **'{appName} is already running on this computer and owns the local daemon. Open the running copy from the system tray, or quit it and retry.'**
  String hostErrorEmbeddedAlreadyRunning(String appName);

  /// Connection failure in a browser for a daemon on the local machine or network, where the browser does not report whether the daemon was down or the Local Network Access permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the daemon. Check that it is running, and that you allowed this site to access your local network.'**
  String get hostErrorLocalNetworkUnreachable;

  /// Connection failure when the running platform has no relay pairing support.
  ///
  /// In en, this message translates to:
  /// **'Relay pairing is not available on this platform.'**
  String get hostErrorRelayPairingUnavailable;

  /// Connection failure when an address now answers as a different daemon than the one saved under this profile.
  ///
  /// In en, this message translates to:
  /// **'That address now reaches a different daemon than the one saved here.'**
  String get hostErrorServerIdentityMismatch;

  /// Connection failure when the stored credential is of the wrong kind for the profile's connection path.
  ///
  /// In en, this message translates to:
  /// **'The stored credential does not match this connection path.'**
  String get hostErrorCredentialMismatch;

  /// Title of the standalone daemon settings page.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettingsTitle;

  /// Heading of the embedded daemon card.
  ///
  /// In en, this message translates to:
  /// **'Local execution'**
  String get appSettingsLocalSection;

  /// Explains the embedded daemon toggle.
  ///
  /// In en, this message translates to:
  /// **'Starts with the app and stops when it exits. A failed start does not block the app.'**
  String get appSettingsEmbeddedSubtitle;

  /// Toggle that binds the embedded daemon to every interface.
  ///
  /// In en, this message translates to:
  /// **'Allow network access'**
  String get appSettingsExposure;

  /// Explains the embedded daemon exposure toggle.
  ///
  /// In en, this message translates to:
  /// **'Off accepts connections from this machine only; on accepts them on every IPv4 interface.'**
  String get appSettingsExposureSubtitle;

  /// Numeric listener port for the embedded daemon.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get appSettingsEmbeddedPort;

  /// Explains the embedded daemon port setting.
  ///
  /// In en, this message translates to:
  /// **'Choose a port from 1 to 65535. Applying restarts the embedded daemon when it is running.'**
  String get appSettingsEmbeddedPortHelp;

  /// Validation message for an invalid embedded daemon port.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 65535.'**
  String get appSettingsEmbeddedPortInvalid;

  /// Saves the embedded daemon port and restarts it when active.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get appSettingsEmbeddedPortApply;

  /// Persistent alert title for an embedded daemon startup or connection failure.
  ///
  /// In en, this message translates to:
  /// **'The embedded daemon could not start'**
  String get appSettingsEmbeddedFailureTitle;

  /// Resolution guidance for an occupied embedded daemon port.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is being used by another process. Choose another port and apply it, or retry after the port becomes available.'**
  String appSettingsEmbeddedPortConflict(int port);

  /// Heading of the remote daemon list.
  ///
  /// In en, this message translates to:
  /// **'Remote daemons'**
  String get appSettingsRemoteSection;

  /// Opens the remote daemon form.
  ///
  /// In en, this message translates to:
  /// **'Add remote daemon'**
  String get appSettingsAddRemote;

  /// No description provided for @relayPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a device'**
  String get relayPairTitle;

  /// No description provided for @relayPairDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code or copy a link to connect your other device to this daemon.'**
  String get relayPairDeviceDescription;

  /// No description provided for @relayPairDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code on your other device, or copy the connection link below.'**
  String get relayPairDialogDescription;

  /// No description provided for @relayConnectDaemonTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a daemon'**
  String get relayConnectDaemonTitle;

  /// No description provided for @relayConnectDaemonDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how to connect to a daemon. Relay links keep daemon traffic end-to-end encrypted.'**
  String get relayConnectDaemonDescription;

  /// No description provided for @relayConnectScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan the one-time QR code shown by the daemon.'**
  String get relayConnectScanDescription;

  /// No description provided for @relayConnectPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste connection link'**
  String get relayConnectPasteTitle;

  /// No description provided for @relayConnectPasteDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste the one-time link shown by the daemon.'**
  String get relayConnectPasteDescription;

  /// No description provided for @relayConnectDirectDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect with a WebSocket address and bearer token.'**
  String get relayConnectDirectDescription;

  /// No description provided for @relayConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Review daemon connection'**
  String get relayConfirmTitle;

  /// No description provided for @relayConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the daemon and relay before registering this device.'**
  String get relayConfirmDescription;

  /// No description provided for @relayConfirmDaemon.
  ///
  /// In en, this message translates to:
  /// **'Daemon ID'**
  String get relayConfirmDaemon;

  /// No description provided for @relayConfirmRelay.
  ///
  /// In en, this message translates to:
  /// **'Relay server'**
  String get relayConfirmRelay;

  /// No description provided for @relayConfirmExpires.
  ///
  /// In en, this message translates to:
  /// **'Link expires'**
  String get relayConfirmExpires;

  /// No description provided for @relayShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get relayShare;

  /// No description provided for @relayRefreshLink.
  ///
  /// In en, this message translates to:
  /// **'Create a new link'**
  String get relayRefreshLink;

  /// No description provided for @relayEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect this daemon through the relay'**
  String get relayEnableTitle;

  /// No description provided for @relayEnableDescription.
  ///
  /// In en, this message translates to:
  /// **'The daemon will open an outbound encrypted connection to the separate Tinyrack relay server so your other devices can reach it.'**
  String get relayEnableDescription;

  /// No description provided for @relayEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Enable relay connection'**
  String get relayEnableAction;

  /// No description provided for @settingsCategoryConnection.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get settingsCategoryConnection;

  /// No description provided for @relayPairDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste the one-time link shown by the daemon. Its code and files stay end-to-end encrypted through the relay.'**
  String get relayPairDescription;

  /// No description provided for @relayPairLink.
  ///
  /// In en, this message translates to:
  /// **'Pairing link'**
  String get relayPairLink;

  /// No description provided for @relayPairDeviceName.
  ///
  /// In en, this message translates to:
  /// **'This device\'s name'**
  String get relayPairDeviceName;

  /// No description provided for @relayPairAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get relayPairAction;

  /// No description provided for @relayPairScan.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get relayPairScan;

  /// No description provided for @relayPairCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'QR scanning is available on Android and iOS. Paste the connection link on this device instead.'**
  String get relayPairCameraUnavailable;

  /// No description provided for @relayPairCameraError.
  ///
  /// In en, this message translates to:
  /// **'{appDisplayName} could not open the camera. Allow camera access in system settings, then try again.'**
  String relayPairCameraError(String appDisplayName);

  /// No description provided for @relayPairCameraRetry.
  ///
  /// In en, this message translates to:
  /// **'Try camera again'**
  String get relayPairCameraRetry;

  /// No description provided for @relayPairQrSemantics.
  ///
  /// In en, this message translates to:
  /// **'QR code for the one-time device connection link'**
  String get relayPairQrSemantics;

  /// No description provided for @relayPairInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid {appDisplayName} pairing link.'**
  String relayPairInvalid(String appDisplayName);

  /// No description provided for @relayPairExpired.
  ///
  /// In en, this message translates to:
  /// **'This pairing link expired or was already used. Create a new link on the daemon.'**
  String get relayPairExpired;

  /// No description provided for @relayPairFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect this daemon. Create a new link on the daemon and try again.'**
  String get relayPairFailed;

  /// No description provided for @relayAdvancedDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct connection'**
  String get relayAdvancedDirect;

  /// No description provided for @relayAdvancedRelayEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Relay server address'**
  String get relayAdvancedRelayEndpoint;

  /// No description provided for @relayAdvancedRelayEndpointChange.
  ///
  /// In en, this message translates to:
  /// **'Change relay server address'**
  String get relayAdvancedRelayEndpointChange;

  /// No description provided for @relayAdvancedRelayEndpointHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the official relay by default, or enter a self-hosted WebSocket endpoint.'**
  String get relayAdvancedRelayEndpointHelp;

  /// No description provided for @relayDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected devices'**
  String get relayDevicesTitle;

  /// No description provided for @relayDevicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a ten-minute link for a new device or remove a device that should no longer connect.'**
  String get relayDevicesDescription;

  /// No description provided for @relayCreateLink.
  ///
  /// In en, this message translates to:
  /// **'Create connection link'**
  String get relayCreateLink;

  /// No description provided for @relayLinkExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {expiresAt}'**
  String relayLinkExpires(String expiresAt);

  /// No description provided for @relayNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices are approved.'**
  String get relayNoDevices;

  /// No description provided for @relayRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get relayRevoke;

  /// No description provided for @relayRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke {name}?'**
  String relayRevokeTitle(String name);

  /// No description provided for @relayRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'The device\'s live relay connection ends immediately. A new pairing link is required to reconnect.'**
  String get relayRevokeBody;

  /// No description provided for @relayPathDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get relayPathDirect;

  /// No description provided for @relayPathRelay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get relayPathRelay;

  /// No description provided for @relayConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Connection details'**
  String get relayConnectionDetails;

  /// No description provided for @relayApprovedDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get relayApprovedDevices;

  /// Empty state of the remote daemon list.
  ///
  /// In en, this message translates to:
  /// **'No remote daemons are saved.'**
  String get appSettingsNoRemotes;

  /// Confirmation title for disabling the embedded daemon.
  ///
  /// In en, this message translates to:
  /// **'Stop the embedded daemon?'**
  String get appSettingsStopEmbeddedTitle;

  /// Explains the blast radius of stopping the embedded daemon.
  ///
  /// In en, this message translates to:
  /// **'This stops only the daemon this app owns, along with its connection. Remote and standalone daemons are unaffected.'**
  String get appSettingsStopEmbeddedBody;

  /// Tooltip that opens the remote daemon form.
  ///
  /// In en, this message translates to:
  /// **'Edit connection'**
  String get appSettingsEditConnection;

  /// Toggle that reconnects a daemon at launch.
  ///
  /// In en, this message translates to:
  /// **'Connect on app start'**
  String get appSettingsAutoConnect;

  /// Retries a daemon connection.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get appSettingsReconnect;

  /// Opens provider settings for one daemon.
  ///
  /// In en, this message translates to:
  /// **'Provider settings'**
  String get appSettingsProviderSettings;

  /// Title of the remote daemon form when creating.
  ///
  /// In en, this message translates to:
  /// **'Add remote daemon'**
  String get appSettingsAddRemoteTitle;

  /// Title of the remote daemon form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit remote daemon'**
  String get appSettingsEditRemoteTitle;

  /// Text field label for the daemon endpoint.
  ///
  /// In en, this message translates to:
  /// **'WebSocket address'**
  String get appSettingsAddress;

  /// Example name shown in the remote daemon name field.
  ///
  /// In en, this message translates to:
  /// **'Production daemon'**
  String get appSettingsLabelPlaceholder;

  /// Text field label for replacing a stored token.
  ///
  /// In en, this message translates to:
  /// **'New bearer token (only when changing it)'**
  String get appSettingsNewToken;

  /// Text field label for the token of a new remote daemon.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get appSettingsBearerToken;

  /// Section heading for a remote daemon's name and address.
  ///
  /// In en, this message translates to:
  /// **'Daemon'**
  String get appSettingsRemoteDetails;

  /// Section heading for how the app connects to a daemon.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get appSettingsConnectionBehaviour;

  /// Alert title shown when a remote daemon fails to save.
  ///
  /// In en, this message translates to:
  /// **'Could not save the connection'**
  String get appSettingsConnectionFailed;

  /// Confirmation title for removing a remote daemon profile.
  ///
  /// In en, this message translates to:
  /// **'Delete {label}?'**
  String appSettingsDeleteTitle(String label);

  /// Explains what deleting a remote daemon profile removes.
  ///
  /// In en, this message translates to:
  /// **'The connection and the bearer token stored on this device are removed too.'**
  String get appSettingsDeleteBody;

  /// Heading of the project list pane.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectSettingsHeading;

  /// Empty state of the project settings list.
  ///
  /// In en, this message translates to:
  /// **'No projects are registered.'**
  String get projectSettingsNoProjects;

  /// Placeholder shown before a project is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a project.'**
  String get projectSettingsSelectProject;

  /// Tooltip that returns to the project list on narrow layouts.
  ///
  /// In en, this message translates to:
  /// **'Project list'**
  String get projectSettingsProjectList;

  /// Subtitle counting registered projects.
  ///
  /// In en, this message translates to:
  /// **'{count} projects'**
  String projectSettingsCount(int count);

  /// Tooltip that copies the .tinest/config.json path.
  ///
  /// In en, this message translates to:
  /// **'Copy file location'**
  String get projectSettingsCopyPath;

  /// Explains how worktree hook commands are executed.
  ///
  /// In en, this message translates to:
  /// **'Write one command per line; they run in order in the daemon host\'s shell. The CODER_WORKTREE_PATH, CODER_PROJECT_PATH, and CODER_BRANCH environment variables are available.'**
  String get projectSettingsHookHelp;

  /// Text field label for setup hooks.
  ///
  /// In en, this message translates to:
  /// **'Setup (after a worktree is created)'**
  String get projectSettingsSetup;

  /// Text field label for teardown hooks.
  ///
  /// In en, this message translates to:
  /// **'Teardown (before a worktree is removed)'**
  String get projectSettingsTeardown;

  /// Heading of the agent list pane.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentSettingsHeading;

  /// Placeholder shown before an agent is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select an agent.'**
  String get agentSettingsSelectAgent;

  /// Empty state shown when the current daemon has no agent definitions.
  ///
  /// In en, this message translates to:
  /// **'No agents are configured.'**
  String get agentSettingsEmpty;

  /// Subtitle counting agent definitions.
  ///
  /// In en, this message translates to:
  /// **'{count} definitions'**
  String agentSettingsCount(int count);

  /// Subtitle of an agent whose definition file no longer parses, so the last good version is shown.
  ///
  /// In en, this message translates to:
  /// **'{mode} · stale'**
  String agentSettingsModeStale(String mode);

  /// Tooltip that opens the agent creation dialog.
  ///
  /// In en, this message translates to:
  /// **'Add agent'**
  String get agentSettingsAdd;

  /// Title of the agent creation dialog.
  ///
  /// In en, this message translates to:
  /// **'Add agent'**
  String get agentSettingsAddTitle;

  /// Tooltip that returns to the agent list on narrow layouts.
  ///
  /// In en, this message translates to:
  /// **'Agent list'**
  String get agentSettingsList;

  /// Tooltip that copies the definition file path.
  ///
  /// In en, this message translates to:
  /// **'Copy file location'**
  String get agentSettingsCopyPath;

  /// Tooltip that restores a built-in agent definition.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get agentSettingsReset;

  /// Toggle that overrides the built-in system prompt.
  ///
  /// In en, this message translates to:
  /// **'Use a custom system prompt'**
  String get agentSettingsCustomPrompt;

  /// Toggle that gives an agent its own concrete model.
  ///
  /// In en, this message translates to:
  /// **'Set a model for this agent'**
  String get agentSettingsUseModel;

  /// Explains the disabled state of the agent model toggle.
  ///
  /// In en, this message translates to:
  /// **'When off, this agent uses the daemon default model.'**
  String get agentSettingsUseModelDescription;

  /// Section heading for an agent's identity fields.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get agentSettingsDefinitionHeading;

  /// Section heading for the custom prompt toggle.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get agentSettingsPromptHeading;

  /// Text field label for an agent's system prompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt (Markdown)'**
  String get agentSettingsSystemPrompt;

  /// Section heading for an agent's model choice.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get agentSettingsModelHeading;

  /// Agent model policy that lets each session select its concrete model.
  ///
  /// In en, this message translates to:
  /// **'Use the session model'**
  String get agentSettingsSessionModel;

  /// Agent model policy that pins one concrete model for every session.
  ///
  /// In en, this message translates to:
  /// **'Pin a model'**
  String get agentSettingsPinnedModel;

  /// Text field label for a pinned provider connection.
  ///
  /// In en, this message translates to:
  /// **'Provider connection ID'**
  String get agentSettingsProviderConnectionId;

  /// Text field label for a pinned model.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get agentSettingsModelId;

  /// Section heading for the Agent-owned plugin harness.
  ///
  /// In en, this message translates to:
  /// **'Agent harness'**
  String get agentSettingsHarnessHeading;

  /// Explains the Agent-level harness configuration.
  ///
  /// In en, this message translates to:
  /// **'The Agent owns exactly one driver, ordered extensions, and its model-visible tools.'**
  String get agentSettingsHarnessDescription;

  /// Select label for the Agent's single model-loop driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get agentSettingsDriver;

  /// Shown when no plugin contributes a driver.
  ///
  /// In en, this message translates to:
  /// **'No plugin driver is installed.'**
  String get agentSettingsNoDrivers;

  /// Section heading for ordered Agent lifecycle extensions.
  ///
  /// In en, this message translates to:
  /// **'Ordered extensions'**
  String get agentSettingsExtensions;

  /// Explains that extension order is significant.
  ///
  /// In en, this message translates to:
  /// **'Extensions run serially in this order.'**
  String get agentSettingsExtensionsDescription;

  /// Accessible label for moving an extension earlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get agentSettingsMoveUp;

  /// Accessible label for moving an extension later.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get agentSettingsMoveDown;

  /// Section heading for individually selectable plugin tools.
  ///
  /// In en, this message translates to:
  /// **'Plugin tools'**
  String get agentSettingsPluginTools;

  /// Explains Agent-level tool selection.
  ///
  /// In en, this message translates to:
  /// **'Every model-visible tool can be switched independently for this Agent.'**
  String get agentSettingsPluginToolsDescription;

  /// Section heading for per-plugin JSON settings.
  ///
  /// In en, this message translates to:
  /// **'Plugin settings'**
  String get agentSettingsPluginSettings;

  /// Explains where plugin settings are stored.
  ///
  /// In en, this message translates to:
  /// **'Settings are stored in this Agent definition as JSON objects.'**
  String get agentSettingsPluginSettingsDescription;

  /// Explains how to remove one pluginSettings map entry.
  ///
  /// In en, this message translates to:
  /// **'Clear the field to remove an existing settings entry.'**
  String get agentSettingsPluginSettingsRemove;

  /// Label for one plugin's JSON settings field.
  ///
  /// In en, this message translates to:
  /// **'{plugin} settings (JSON)'**
  String agentSettingsPluginSettingsLabel(String plugin);

  /// Section heading for Agent-scoped plugin grants.
  ///
  /// In en, this message translates to:
  /// **'Plugin capabilities'**
  String get agentSettingsCapabilities;

  /// Explains capability grant storage and scope.
  ///
  /// In en, this message translates to:
  /// **'Grants are kept in daemon state for this Agent, not in the editable Agent file.'**
  String get agentSettingsCapabilitiesDescription;

  /// Empty state for Agent plugin grants.
  ///
  /// In en, this message translates to:
  /// **'The selected plugins request no capabilities.'**
  String get agentSettingsNoCapabilities;

  /// Title for computed Agent harness validation messages.
  ///
  /// In en, this message translates to:
  /// **'Harness diagnostics'**
  String get agentSettingsHarnessDiagnostics;

  /// Diagnostic for a missing driver, extension, tool, or plugin.
  ///
  /// In en, this message translates to:
  /// **'Configured {kind} is unavailable: {id}'**
  String agentSettingsHarnessMissing(String kind, String id);

  /// No description provided for @agentSettingsHarnessKindDriver.
  ///
  /// In en, this message translates to:
  /// **'driver'**
  String get agentSettingsHarnessKindDriver;

  /// No description provided for @agentSettingsHarnessKindExtension.
  ///
  /// In en, this message translates to:
  /// **'extension'**
  String get agentSettingsHarnessKindExtension;

  /// No description provided for @agentSettingsHarnessKindTool.
  ///
  /// In en, this message translates to:
  /// **'tool'**
  String get agentSettingsHarnessKindTool;

  /// No description provided for @agentSettingsHarnessKindPlugin.
  ///
  /// In en, this message translates to:
  /// **'plugin'**
  String get agentSettingsHarnessKindPlugin;

  /// No description provided for @agentSettingsHarnessKindDependency.
  ///
  /// In en, this message translates to:
  /// **'dependency'**
  String get agentSettingsHarnessKindDependency;

  /// No description provided for @agentSettingsHarnessKindModel.
  ///
  /// In en, this message translates to:
  /// **'model'**
  String get agentSettingsHarnessKindModel;

  /// Diagnostic for a driver and model capability mismatch.
  ///
  /// In en, this message translates to:
  /// **'The selected model does not satisfy driver capability: {capability}'**
  String agentSettingsHarnessModelMismatch(String capability);

  /// Diagnostic for malformed plugin JSON settings.
  ///
  /// In en, this message translates to:
  /// **'{plugin} settings must be a valid JSON object.'**
  String agentSettingsHarnessInvalidSettings(String plugin);

  /// Status while the Agent plugin catalog loads.
  ///
  /// In en, this message translates to:
  /// **'Loading plugin contributions…'**
  String get agentSettingsPluginsLoading;

  /// Section heading for reasoning and permission.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get agentSettingsBehaviourHeading;

  /// Row label for the reasoning effort select.
  ///
  /// In en, this message translates to:
  /// **'Reasoning effort'**
  String get agentSettingsReasoning;

  /// Row label for the permission mode select.
  ///
  /// In en, this message translates to:
  /// **'Permission mode'**
  String get agentSettingsPermission;

  /// Heading of the tool permission list.
  ///
  /// In en, this message translates to:
  /// **'Built-in tools'**
  String get agentSettingsBuiltinTools;

  /// Tool group covering workspace search and reading.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get agentSettingsToolGroupFilesystem;

  /// Tool group covering workspace file changes.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get agentSettingsToolGroupEditing;

  /// Tool group covering shell and process execution.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get agentSettingsToolGroupExecution;

  /// Tool group covering conversation attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get agentSettingsToolGroupAttachments;

  /// Tool group covering MCP servers and their resources.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get agentSettingsToolGroupMcp;

  /// Tool group covering collaborating subagents.
  ///
  /// In en, this message translates to:
  /// **'Collaboration'**
  String get agentSettingsToolGroupCollaboration;

  /// Tool group covering plans, questions, and time.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get agentSettingsToolGroupSession;

  /// Subtitle counting the enabled tools in one group.
  ///
  /// In en, this message translates to:
  /// **'{enabled} of {total} on'**
  String agentSettingsToolGroupSummary(int enabled, int total);

  /// Heading of the subagent list.
  ///
  /// In en, this message translates to:
  /// **'Callable subagents'**
  String get agentSettingsSubagents;

  /// Empty state of the subagent list.
  ///
  /// In en, this message translates to:
  /// **'No subagents are registered.'**
  String get agentSettingsNoSubagents;

  /// Asks whether to archive an agent definition.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String agentSettingsArchiveTitle(String name);

  /// Explains what archiving an agent definition does before it happens.
  ///
  /// In en, this message translates to:
  /// **'Sessions already using this agent keep running. It stops being offered for new ones.'**
  String get agentSettingsArchiveBody;

  /// Asks whether to restore a built-in agent definition.
  ///
  /// In en, this message translates to:
  /// **'Reset {name} to defaults?'**
  String agentSettingsResetTitle(String name);

  /// Explains that resetting a built-in agent discards local edits.
  ///
  /// In en, this message translates to:
  /// **'Every edit made to this built-in agent is discarded and cannot be recovered.'**
  String get agentSettingsResetBody;

  /// Reported when an agent definition could not be archived.
  ///
  /// In en, this message translates to:
  /// **'Could not archive the agent.'**
  String get agentSettingsArchiveFailed;

  /// Reported when the built-in agent definition could not be restored.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the built-in agent.'**
  String get agentSettingsResetFailed;

  /// Reported after an agent definition is archived and the editor closes.
  ///
  /// In en, this message translates to:
  /// **'Archived.'**
  String get agentSettingsArchived;

  /// Reported after the built-in agent definition is restored. Distinct from agentSettingsReset, which labels the button.
  ///
  /// In en, this message translates to:
  /// **'Restored the built-in agent.'**
  String get agentSettingsResetDone;

  /// Title of the save conflict dialog.
  ///
  /// In en, this message translates to:
  /// **'Could not save the agent'**
  String get agentSettingsSaveFailedTitle;

  /// Discards local edits and reloads the definition.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get agentSettingsReload;

  /// Writes local edits over the newer definition.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get agentSettingsOverwrite;

  /// Validation error for an agent ID.
  ///
  /// In en, this message translates to:
  /// **'Only lowercase letters, digits, -, and _ are allowed.'**
  String get agentSettingsIdInvalid;

  /// Validation error for a duplicate agent ID.
  ///
  /// In en, this message translates to:
  /// **'That agent ID already exists.'**
  String get agentSettingsIdTaken;

  /// Text field label for the agent ID.
  ///
  /// In en, this message translates to:
  /// **'ID (file name)'**
  String get agentSettingsIdLabel;

  /// Validation error for an empty agent name.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get agentSettingsNameRequired;

  /// Title of the standalone provider settings page.
  ///
  /// In en, this message translates to:
  /// **'Provider settings'**
  String get providerSettingsTitle;

  /// Shown when provider settings has no daemon state.
  ///
  /// In en, this message translates to:
  /// **'Connect a daemon first.'**
  String get providerSettingsRequiresDaemon;

  /// Tooltip that reloads the provider catalog.
  ///
  /// In en, this message translates to:
  /// **'Refresh catalog'**
  String get providerSettingsRefreshCatalog;

  /// No description provided for @providerSettingsCatalogStatus.
  ///
  /// In en, this message translates to:
  /// **'Catalog metadata'**
  String get providerSettingsCatalogStatus;

  /// No description provided for @providerSettingsCatalogBundled.
  ///
  /// In en, this message translates to:
  /// **'Bundled snapshot'**
  String get providerSettingsCatalogBundled;

  /// No description provided for @providerSettingsCatalogCached.
  ///
  /// In en, this message translates to:
  /// **'Last-known-good cache'**
  String get providerSettingsCatalogCached;

  /// No description provided for @providerSettingsCatalogFresh.
  ///
  /// In en, this message translates to:
  /// **'Recently refreshed'**
  String get providerSettingsCatalogFresh;

  /// No description provided for @providerSettingsCatalogStale.
  ///
  /// In en, this message translates to:
  /// **'Refresh due; local metadata remains available'**
  String get providerSettingsCatalogStale;

  /// Section title of the daemon-wide concrete model.
  ///
  /// In en, this message translates to:
  /// **'Daemon default model'**
  String get modelSettingsSection;

  /// Explains the daemon model priority.
  ///
  /// In en, this message translates to:
  /// **'New chats use this model when neither the chat nor its agent specifies one.'**
  String get modelSettingsSectionDescription;

  /// Warning title for a concrete model that cannot currently run.
  ///
  /// In en, this message translates to:
  /// **'Saved model unavailable'**
  String get modelSettingsUnavailableTitle;

  /// Warning for an unavailable saved model.
  ///
  /// In en, this message translates to:
  /// **'{modelId} cannot run. Choose another model before starting a chat.'**
  String modelSettingsUnavailableDescription(String modelId);

  /// Reported when the daemon default model could not be stored.
  ///
  /// In en, this message translates to:
  /// **'Could not update the daemon default model'**
  String get modelSettingsSaveFailed;

  /// Title of the sheet choosing how to connect one provider.
  ///
  /// In en, this message translates to:
  /// **'{name} connection'**
  String providerSettingsAuthTitle(String name);

  /// Subtitle marking an experimental auth method.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get providerSettingsExperimental;

  /// Title of the disconnect confirmation.
  ///
  /// In en, this message translates to:
  /// **'Disconnect provider'**
  String get providerSettingsDisconnectTitle;

  /// Explains what disconnecting a provider keeps.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {name}? Existing agent history is kept.'**
  String providerSettingsDisconnectBody(String name);

  /// Confirms disconnecting a provider.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get providerSettingsDisconnect;

  /// Title of the custom provider deletion confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete custom provider'**
  String get providerSettingsDeleteCustomTitle;

  /// Explains what deleting a custom provider removes and keeps.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and its stored credentials? Existing session history is kept.'**
  String providerSettingsDeleteCustomBody(String name);

  /// Heading of the connected provider list.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get providerSettingsConnected;

  /// Empty state of the connected provider list.
  ///
  /// In en, this message translates to:
  /// **'No providers are connected.'**
  String get providerSettingsNoConnections;

  /// Empty detail pane shown before a provider is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a provider to manage.'**
  String get providerSettingsSelectConnection;

  /// No description provided for @providerSettingsRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Name and Base URL are required.'**
  String get providerSettingsRequiredFields;

  /// No description provided for @providerSettingsApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API key is required.'**
  String get providerSettingsApiKeyRequired;

  /// Menu entry that opens the custom provider form.
  ///
  /// In en, this message translates to:
  /// **'Edit advanced settings'**
  String get providerSettingsEditAdvanced;

  /// No description provided for @providerSettingsActions.
  ///
  /// In en, this message translates to:
  /// **'Connection actions'**
  String get providerSettingsActions;

  /// Heading of the provider catalog.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get providerSettingsAdd;

  /// Empty state of the provider catalog.
  ///
  /// In en, this message translates to:
  /// **'No presets are left to add.'**
  String get providerSettingsNoPresets;

  /// Subtitle of the custom provider catalog entry.
  ///
  /// In en, this message translates to:
  /// **'Advanced: connect your own endpoint'**
  String get providerSettingsCustomSubtitle;

  /// Title of the custom provider catalog entry.
  ///
  /// In en, this message translates to:
  /// **'Custom Provider'**
  String get providerSettingsCustomName;

  /// Alert title shown when the provider catalog fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the catalog'**
  String get providerSettingsRefreshFailed;

  /// Title of the pending OAuth attempt bar.
  ///
  /// In en, this message translates to:
  /// **'Waiting for sign-in'**
  String get providerSettingsOAuthPending;

  /// Action that reopens a provider OAuth URL in the system browser.
  ///
  /// In en, this message translates to:
  /// **'Open browser'**
  String get providerSettingsOpenBrowser;

  /// Action that replaces credentials for an existing provider connection.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get providerSettingsReconnect;

  /// Label for the globally unique provider model prefix.
  ///
  /// In en, this message translates to:
  /// **'Model prefix'**
  String get providerSettingsModelPrefix;

  /// Help text explaining qualified model identifiers.
  ///
  /// In en, this message translates to:
  /// **'Used in model IDs such as openai/gpt-5.6-col.'**
  String get providerSettingsModelPrefixHelp;

  /// Validation message for an invalid model prefix.
  ///
  /// In en, this message translates to:
  /// **'Use 1–64 lowercase letters, numbers, hyphens, or underscores.'**
  String get providerSettingsModelPrefixInvalid;

  /// Inline error shown when the daemon rejects a duplicate model prefix.
  ///
  /// In en, this message translates to:
  /// **'That model prefix is already in use. Try the updated suggestion.'**
  String get providerSettingsModelPrefixConflict;

  /// Heading of the section reporting one provider connection's status. Distinct from the Connections settings category, which lists daemons.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get providerSettingsConnectionHeading;

  /// Title of the API key dialog.
  ///
  /// In en, this message translates to:
  /// **'Connect {name}'**
  String providerSettingsConnectTitle(String name);

  /// Confirms the API key dialog.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get providerSettingsConnect;

  /// Text field label for a provider API key.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providerSettingsApiKey;

  /// Text field label for a custom provider endpoint.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providerSettingsBaseUrl;

  /// Fallback shown when a provider connection fails without naming a reason.
  ///
  /// In en, this message translates to:
  /// **'Provider connection failed.'**
  String get providerSettingsConnectionFailed;

  /// Reported when no browser could be launched for an OAuth sign-in.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the authorization page.'**
  String get providerSettingsAuthUrlFailed;

  /// Title of the custom provider dialog.
  ///
  /// In en, this message translates to:
  /// **'Custom provider advanced settings'**
  String get providerSettingsCustomTitle;

  /// Dropdown label for the provider wire format.
  ///
  /// In en, this message translates to:
  /// **'API format'**
  String get providerSettingsApiFormat;

  /// Toggle marking a custom provider as authenticated.
  ///
  /// In en, this message translates to:
  /// **'Requires an API key'**
  String get providerSettingsRequiresApiKey;

  /// Text field label for one hand-entered model identifier.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get providerSettingsManualModelId;

  /// Button that appends another hand-entered model.
  ///
  /// In en, this message translates to:
  /// **'Add model'**
  String get providerSettingsManualModelAdd;

  /// Accessible name of the button removing a manual model.
  ///
  /// In en, this message translates to:
  /// **'Remove model'**
  String get providerSettingsManualModelRemove;

  /// Label of the field naming the values one control accepts.
  ///
  /// In en, this message translates to:
  /// **'{control} values'**
  String providerSettingsControlValues(String control);

  /// Helper text under the control value field.
  ///
  /// In en, this message translates to:
  /// **'Type a value and select it to add. Only whoever runs this endpoint knows which values it accepts.'**
  String get providerSettingsControlValuesHelp;

  /// Placeholder of the control value field.
  ///
  /// In en, this message translates to:
  /// **'Type a value'**
  String get providerSettingsControlValuesPlaceholder;

  /// Error shown when a selected choice control has no values.
  ///
  /// In en, this message translates to:
  /// **'Add at least one value for {control}, or turn it off.'**
  String providerSettingsControlValuesRequired(String control);

  /// Title of the manual model dialog.
  ///
  /// In en, this message translates to:
  /// **'Could not list models'**
  String get providerSettingsModelLookupFailedTitle;

  /// Explains why manual model IDs are needed.
  ///
  /// In en, this message translates to:
  /// **'The provider did not return a model list. Enter the model IDs to use.'**
  String get providerSettingsModelLookupFailedBody;

  /// Dismisses the manual model dialog without saving.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get providerSettingsLater;

  /// Provider connection status.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get providerStatusConnecting;

  /// Provider connection status.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get providerStatusConnected;

  /// Provider connection status.
  ///
  /// In en, this message translates to:
  /// **'Limited connection'**
  String get providerStatusDegraded;

  /// Provider connection status.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get providerStatusError;

  /// Provider connection status.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get providerStatusReauthRequired;

  /// Provider connection status.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get providerStatusDisconnected;

  /// Origin of a provider credential.
  ///
  /// In en, this message translates to:
  /// **'Stored credential'**
  String get providerAuthStored;

  /// Credential label for a connection authorized over OAuth.
  ///
  /// In en, this message translates to:
  /// **'OAuth'**
  String get providerAuthOAuth;

  /// Origin of a provider credential.
  ///
  /// In en, this message translates to:
  /// **'No credential'**
  String get providerAuthNone;

  /// Title of the model picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get modelPickerTitle;

  /// Search field label of the model picker.
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get modelPickerSearch;

  /// Empty state of the model picker search.
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get modelPickerNoResults;

  /// Tooltip of the agent selector.
  ///
  /// In en, this message translates to:
  /// **'Select an agent'**
  String get composerSelectAgent;

  /// Label of the composer agent setting.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get composerAgent;

  /// Tooltip explaining why the agent selector is disabled.
  ///
  /// In en, this message translates to:
  /// **'The agent cannot be changed after the session starts.'**
  String get composerAgentLocked;

  /// Fallback label of the model selector.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get composerModel;

  /// Tooltip and title of the model selector.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get composerSelectModel;

  /// Placeholder shown before the first session exists.
  ///
  /// In en, this message translates to:
  /// **'Start a new session with a coding request.'**
  String get composerStartHint;

  /// Explains why the composer is disabled.
  ///
  /// In en, this message translates to:
  /// **'No primary agent is available.'**
  String get composerNoPrimaryAgent;

  /// Explains why the composer is disabled.
  ///
  /// In en, this message translates to:
  /// **'Connect a provider first.'**
  String get composerConnectProviderFirst;

  /// Hint of the composer text field.
  ///
  /// In en, this message translates to:
  /// **'Type a coding request…'**
  String get composerInputHint;

  /// Label of the composer reasoning effort chip when inheriting.
  ///
  /// In en, this message translates to:
  /// **'Effort'**
  String get composerReasoningEffort;

  /// Tooltip of the composer reasoning effort chip.
  ///
  /// In en, this message translates to:
  /// **'Select reasoning effort'**
  String get composerSelectReasoningEffort;

  /// Menu entry restoring the agent definition reasoning effort.
  ///
  /// In en, this message translates to:
  /// **'Agent default'**
  String get composerInheritReasoningEffort;

  /// Label of the composer permission mode chip when inheriting.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get composerPermissionMode;

  /// Tooltip of the composer permission mode chip.
  ///
  /// In en, this message translates to:
  /// **'Select permissions'**
  String get composerSelectPermissionMode;

  /// Permission mode allowing read-only tools.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get composerPermissionReadOnly;

  /// Permission mode asking before every mutation.
  ///
  /// In en, this message translates to:
  /// **'Ask before changes'**
  String get composerPermissionAsk;

  /// Permission mode allowing workspace writes without asking.
  ///
  /// In en, this message translates to:
  /// **'Workspace access'**
  String get composerPermissionWorkspaceWrite;

  /// No description provided for @composerPermissionFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full access'**
  String get composerPermissionFullAccess;

  /// No description provided for @permissionPickerDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what the agent may do without asking.'**
  String get permissionPickerDescription;

  /// No description provided for @permissionDescriptionReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Can read files. File changes, commands, and write-capable external tools are blocked.'**
  String get permissionDescriptionReadOnly;

  /// No description provided for @permissionDescriptionAsk.
  ///
  /// In en, this message translates to:
  /// **'Reads without asking. Asks before file changes, commands, and write-capable external tools.'**
  String get permissionDescriptionAsk;

  /// No description provided for @permissionDescriptionWorkspaceWrite.
  ///
  /// In en, this message translates to:
  /// **'Can read and edit workspace files. Asks before commands and write-capable external tools.'**
  String get permissionDescriptionWorkspaceWrite;

  /// No description provided for @permissionDescriptionFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Runs file changes, commands, and external tools without asking. Use only for trusted work.'**
  String get permissionDescriptionFullAccess;

  /// No description provided for @permissionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionSettingsTitle;

  /// No description provided for @permissionSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Default permissions'**
  String get permissionSettingsSection;

  /// No description provided for @permissionSettingsSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Agents that do not choose their own permissions inherit this daemon default.'**
  String get permissionSettingsSectionDescription;

  /// No description provided for @permissionSettingsChange.
  ///
  /// In en, this message translates to:
  /// **'Change default permissions'**
  String get permissionSettingsChange;

  /// No description provided for @permissionSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update default permissions'**
  String get permissionSettingsSaveFailed;

  /// No description provided for @permissionChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change permissions'**
  String get permissionChangeFailed;

  /// No description provided for @permissionSettingsDaemonDefault.
  ///
  /// In en, this message translates to:
  /// **'Daemon default'**
  String get permissionSettingsDaemonDefault;

  /// Label of the composer fast mode toggle.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get composerFastMode;

  /// Tooltip of the composer fast mode toggle when it is off.
  ///
  /// In en, this message translates to:
  /// **'Faster responses at a higher credit rate'**
  String get composerFastModeTooltip;

  /// Tooltip of the composer fast mode toggle when it is on.
  ///
  /// In en, this message translates to:
  /// **'Fast mode is on; tap to use the standard tier'**
  String get composerFastModeOnTooltip;

  /// Tooltip shown when a composer setting cannot change mid-turn.
  ///
  /// In en, this message translates to:
  /// **'Settings change between turns'**
  String get composerSettingLocked;

  /// Accessible label for the composer send button.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get composerSendLabel;

  /// Accessible label for the send button while a turn runs.
  ///
  /// In en, this message translates to:
  /// **'Queue message'**
  String get composerQueueLabel;

  /// Tooltip of the send button while a turn runs.
  ///
  /// In en, this message translates to:
  /// **'Sends when the current turn finishes'**
  String get composerQueueTooltip;

  /// Action returning a queued message to the input.
  ///
  /// In en, this message translates to:
  /// **'Edit queued message'**
  String get composerQueuedEdit;

  /// Action stopping the current turn to send a queued message.
  ///
  /// In en, this message translates to:
  /// **'Send queued message now'**
  String get composerQueuedSendNow;

  /// Summary of the files attached to a queued message.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String composerQueuedAttachments(num count);

  /// Why a queued message stopped trying to send.
  ///
  /// In en, this message translates to:
  /// **'Not sent · {reason}'**
  String composerQueuedFailed(String reason);

  /// Accessible label for the composer attachment button.
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get composerAttachLabel;

  /// Accessible label of the button removing one pending attachment.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String composerRemoveAttachment(String name);

  /// Reported when one chosen file is over the per-attachment size limit.
  ///
  /// In en, this message translates to:
  /// **'Each attachment must be under {limit} MB.'**
  String composerAttachmentTooLarge(int limit);

  /// Reported when a submission would hold more files than one turn accepts.
  ///
  /// In en, this message translates to:
  /// **'A turn accepts at most {limit} files.'**
  String composerAttachmentTooMany(int limit);

  /// Label and title of the compact composer settings sheet.
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get composerMoreSettings;

  /// Choice that removes an explicit model-control override.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get composerUseDefault;

  /// Choice that enables a toggle model control.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get composerEnabled;

  /// Empty state of the chat timeline.
  ///
  /// In en, this message translates to:
  /// **'Type a coding request.'**
  String get chatEmptyTitle;

  /// Example request shown in the empty chat timeline.
  ///
  /// In en, this message translates to:
  /// **'e.g. Run the tests and fix what fails'**
  String get chatEmptyExample;

  /// Timeline notice for a cancelled turn.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get chatNoticeCancelled;

  /// Timeline notice for a failed turn.
  ///
  /// In en, this message translates to:
  /// **'Failed · {message}'**
  String chatNoticeFailed(String message);

  /// Copies an assistant response to the clipboard as Markdown.
  ///
  /// In en, this message translates to:
  /// **'Copy response'**
  String get chatCopyResponse;

  /// Marks the lines hidden by a collapsed code or diff block.
  ///
  /// In en, this message translates to:
  /// **'… {count} more lines'**
  String chatMoreLines(int count);

  /// Title of the tool approval card.
  ///
  /// In en, this message translates to:
  /// **'Approval required · {tool}'**
  String chatApprovalRequired(String tool);

  /// Rejects a tool call.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get chatApprovalDeny;

  /// Approves a tool call.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get chatApprovalAllow;

  /// Prompt token count in the usage summary line.
  ///
  /// In en, this message translates to:
  /// **'in {tokens}'**
  String usageInput(int tokens);

  /// Prompt tokens with the cached portion called out.
  ///
  /// In en, this message translates to:
  /// **'in {tokens} ({cached} cached)'**
  String usageInputCached(int tokens, int cached);

  /// Completion token count in the usage summary line.
  ///
  /// In en, this message translates to:
  /// **'out {tokens}'**
  String usageOutput(int tokens);

  /// Completion tokens with the hidden reasoning portion called out.
  ///
  /// In en, this message translates to:
  /// **'out {tokens} ({reasoning} reasoning)'**
  String usageOutputReasoning(int tokens, int reasoning);

  /// Total token count in the usage summary line.
  ///
  /// In en, this message translates to:
  /// **'total {tokens}'**
  String usageTotal(int tokens);

  /// Output tokens per second, measured over the time the response streamed and excluding tool execution. The caller rounds the rate; decimalPattern only localizes the separators.
  ///
  /// In en, this message translates to:
  /// **'{rate} tok/s'**
  String usageThroughput(double rate);

  /// A free-form answer the user typed instead of choosing.
  ///
  /// In en, this message translates to:
  /// **'{answer} (typed)'**
  String chatAnswerTyped(String answer);

  /// Label of the sleep countdown card.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get chatSleepWaiting;

  /// Remaining time on the sleep countdown.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s left'**
  String chatSleepRemaining(int seconds);

  /// Shown once a sleep has finished.
  ///
  /// In en, this message translates to:
  /// **'Waited {seconds}s'**
  String chatSleepDone(int seconds);

  /// Heading above subagent approvals shown on the parent session.
  ///
  /// In en, this message translates to:
  /// **'Subagent approvals'**
  String get subagentApprovalSection;

  /// Semantic label of the session tab flag for a blocked subagent.
  ///
  /// In en, this message translates to:
  /// **'A subagent is waiting for approval'**
  String get subagentTabAwaitingApproval;

  /// Semantics label of work that is queued but not started.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// Semantics label of work in progress.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get statusRunning;

  /// Semantics label of work parked on a user decision.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get statusBlocked;

  /// Semantics label of work stopped on request.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get statusPaused;

  /// Semantics label of work that finished successfully.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusDone;

  /// Semantics label of work that finished with an error.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// Result line of a queued inter-agent message.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get chatToolSubagentQueued;

  /// Result line of the collaboration agent list.
  ///
  /// In en, this message translates to:
  /// **'{count} agents'**
  String chatToolSubagentCount(int count);

  /// Notice that some tools were not advertised up front.
  ///
  /// In en, this message translates to:
  /// **'{count} tools are available through search'**
  String chatDeferredTools(int count);

  /// Button that submits answers to the agent's questions.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get chatQuestionSubmit;

  /// Button that advances to the next agent question.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get chatQuestionNext;

  /// Screen-reader name of the agent question tab strip.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get chatQuestionNavigation;

  /// Screen-reader status while agent question answers are submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitting answers'**
  String get chatQuestionSubmitting;

  /// Choice that lets the user type a free-form answer.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chatQuestionOther;

  /// Placeholder of the free-form answer field.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get chatQuestionOtherPlaceholder;

  /// Result line of a denied tool call.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get toolRejected;

  /// Result line of a tool call with no error text.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get toolFailed;

  /// Title of the remote directory browser.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder on the daemon'**
  String get directoryBrowserTitle;

  /// Text field label for the browsed path.
  ///
  /// In en, this message translates to:
  /// **'Daemon path'**
  String get directoryBrowserPath;

  /// Empty state of the directory listing.
  ///
  /// In en, this message translates to:
  /// **'No subfolders.'**
  String get directoryBrowserEmpty;

  /// Confirms the browsed folder.
  ///
  /// In en, this message translates to:
  /// **'Choose this folder'**
  String get directoryBrowserSelect;

  /// Title of the daemon picker shown before browsing.
  ///
  /// In en, this message translates to:
  /// **'Daemon to add the folder to'**
  String get directoryBrowserHostTitle;

  /// Line naming a worktree hook that failed, listed in the dialog that reports the failure.
  ///
  /// In en, this message translates to:
  /// **'{phase} failed (exit {exitCode}): {command}'**
  String hookFailureMessage(String phase, int exitCode, String command);

  /// Title of the hook failure detail dialog.
  ///
  /// In en, this message translates to:
  /// **'{phase} hook failed'**
  String hookFailureTitle(String phase);

  /// Stands in for a hook that produced no output.
  ///
  /// In en, this message translates to:
  /// **'(no output)'**
  String get hookFailureNoOutput;

  /// Sidebar label for the skill settings category.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get settingsCategorySkill;

  /// Heading above the read-only skill catalog.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillSettingsHeading;

  /// Label for choosing the global or project skill catalog.
  ///
  /// In en, this message translates to:
  /// **'Skill scope'**
  String get skillSettingsScope;

  /// Scope option showing skills defined outside a project.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get skillSettingsScopeGlobal;

  /// Explains that inherited and shadowed skills are omitted.
  ///
  /// In en, this message translates to:
  /// **'Shows only effective skills defined in the selected scope.'**
  String get skillSettingsScopeHint;

  /// Number of effective global skills.
  ///
  /// In en, this message translates to:
  /// **'{count} global skills'**
  String skillSettingsGlobalCount(int count);

  /// Number of effective skills defined by the selected project.
  ///
  /// In en, this message translates to:
  /// **'{count} project skills'**
  String skillSettingsProjectCount(int count);

  /// Empty state for the global skill catalog.
  ///
  /// In en, this message translates to:
  /// **'No global skills are available.'**
  String get skillSettingsGlobalEmpty;

  /// Empty state for a project's own effective skills.
  ///
  /// In en, this message translates to:
  /// **'No skills are available in this project.'**
  String get skillSettingsProjectEmpty;

  /// Placeholder for filtering the project scope options.
  ///
  /// In en, this message translates to:
  /// **'Search projects'**
  String get skillSettingsProjectSearch;

  /// Shown when the project filter matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No matching project'**
  String get skillSettingsProjectNoMatch;

  /// Sidebar label for the MCP server settings category.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get settingsCategoryMcp;

  /// Heading of the MCP server list.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get mcpSettingsHeading;

  /// Tooltip of the add-server button.
  ///
  /// In en, this message translates to:
  /// **'Add MCP server'**
  String get mcpSettingsAdd;

  /// Shown when no server exists.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers are configured.'**
  String get mcpSettingsEmpty;

  /// Placeholder in the detail pane.
  ///
  /// In en, this message translates to:
  /// **'Select a server to edit it.'**
  String get mcpSettingsSelectServer;

  /// Heading above servers the user configured.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get mcpSettingsScopeUser;

  /// Heading above servers the repository declares.
  ///
  /// In en, this message translates to:
  /// **'This project'**
  String get mcpSettingsScopeProject;

  /// Explains why a project server is read-only.
  ///
  /// In en, this message translates to:
  /// **'Defined by this repository, so {appName} does not edit it.'**
  String mcpSettingsProjectReadOnly(String appName);

  /// Badge on a project server a user server overrides.
  ///
  /// In en, this message translates to:
  /// **'Hidden by your server of the same name'**
  String get mcpSettingsShadowed;

  /// Shows which file declares a server.
  ///
  /// In en, this message translates to:
  /// **'Defined in {path}'**
  String mcpSettingsSource(String path);

  /// Label of the server id field.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get mcpSettingsServerId;

  /// Rejects an unusable server id.
  ///
  /// In en, this message translates to:
  /// **'Use lower-case letters, digits, - and _.'**
  String get mcpSettingsServerIdInvalid;

  /// Label of the transport selector.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get mcpSettingsTransport;

  /// Label of the stdio transport.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpSettingsTransportStdio;

  /// Label of the Streamable HTTP transport.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get mcpSettingsTransportHttp;

  /// Label of the executable field.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpSettingsCommand;

  /// Label of the arguments field.
  ///
  /// In en, this message translates to:
  /// **'Arguments (one per line)'**
  String get mcpSettingsArgs;

  /// Label of the cwd field.
  ///
  /// In en, this message translates to:
  /// **'Working directory (optional)'**
  String get mcpSettingsWorkingDirectory;

  /// Label of the endpoint field.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get mcpSettingsUrl;

  /// Label of the env field.
  ///
  /// In en, this message translates to:
  /// **'Environment (KEY=value, one per line)'**
  String get mcpSettingsEnvironment;

  /// Label of the headers field.
  ///
  /// In en, this message translates to:
  /// **'Headers (Name: value, one per line)'**
  String get mcpSettingsHeaders;

  /// Section heading for an MCP server's transport fields.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get mcpSettingsConnectionHeading;

  /// Section heading for whether an MCP server is enabled.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get mcpSettingsStateHeading;

  /// Label of the enable switch.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get mcpSettingsEnabled;

  /// Explains the secret reference syntax.
  ///
  /// In en, this message translates to:
  /// **'Never paste a secret here. Reference a stored secret or an environment variable instead:'**
  String get mcpSettingsSecretHint;

  /// Label of the test button.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get mcpSettingsTest;

  /// Reports a successful test.
  ///
  /// In en, this message translates to:
  /// **'Connected and found {count} tools.'**
  String mcpSettingsTestSucceeded(int count);

  /// Reports a failed test.
  ///
  /// In en, this message translates to:
  /// **'Could not connect: {error}'**
  String mcpSettingsTestFailed(String error);

  /// Reported when a running terminal could not be terminated, so its tab stays open.
  ///
  /// In en, this message translates to:
  /// **'Could not stop the terminal.'**
  String get terminalTerminateFailed;

  /// Reported when a paired relay device could not be revoked.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke the device.'**
  String get relayRevokeFailed;

  /// Reported when a daemon preference could not be stored or applied.
  ///
  /// In en, this message translates to:
  /// **'Could not change the daemon setting.'**
  String get appSettingsDaemonChangeFailed;

  /// Reported when a remote daemon profile could not be deleted.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the daemon.'**
  String get appSettingsDeleteFailed;

  /// Reported when a remote daemon could not be reconnected.
  ///
  /// In en, this message translates to:
  /// **'Could not reconnect.'**
  String get appSettingsReconnectFailed;

  /// Reported when a provider connection could not be removed.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect the provider.'**
  String get providerSettingsDisconnectFailed;

  /// Reported when a custom provider could not be deleted.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the provider.'**
  String get providerSettingsDeleteFailed;

  /// Reported after a provider connection is removed.
  ///
  /// In en, this message translates to:
  /// **'Disconnected.'**
  String get providerSettingsDisconnected;

  /// Reported when a worktree could not be archived.
  ///
  /// In en, this message translates to:
  /// **'Could not archive the worktree.'**
  String get workspaceArchiveFailed;

  /// Reported when a project could not be unregistered.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the project.'**
  String get workspaceUnregisterFailed;

  /// Reported when a project's hooks or shell could not be written.
  ///
  /// In en, this message translates to:
  /// **'Could not save the project settings.'**
  String get projectSettingsSaveFailed;

  /// Reported when an MCP server could not be added or updated.
  ///
  /// In en, this message translates to:
  /// **'Could not save the server.'**
  String get mcpSettingsSaveFailed;

  /// Reported when an MCP server could not be removed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the server.'**
  String get mcpSettingsDeleteFailed;

  /// Reported when an MCP secret could not be written.
  ///
  /// In en, this message translates to:
  /// **'Could not store the secret.'**
  String get mcpSettingsSecretFailed;

  /// Label of the delete action.
  ///
  /// In en, this message translates to:
  /// **'Delete server'**
  String get mcpSettingsDelete;

  /// Confirms deleting a server.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? Agents using its tools will lose them.'**
  String mcpSettingsDeleteConfirm(String name);

  /// Server status label.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mcpSettingsStatusDisabled;

  /// Server status label.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get mcpSettingsStatusConnecting;

  /// Accessible label of the spinner shown while an MCP server connects.
  ///
  /// In en, this message translates to:
  /// **'Connecting MCP server'**
  String get mcpSettingsConnecting;

  /// Server status label.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get mcpSettingsStatusReady;

  /// Server status label.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mcpSettingsStatusFailed;

  /// Label for the resource count in the MCP server list row.
  ///
  /// In en, this message translates to:
  /// **'resources'**
  String get mcpSettingsDiscoveredResources;

  /// Heading of the collapsible MCP resource list.
  ///
  /// In en, this message translates to:
  /// **'Published resources'**
  String get mcpSettingsResources;

  /// Empty state of the MCP resource list.
  ///
  /// In en, this message translates to:
  /// **'This server publishes no resources.'**
  String get mcpSettingsNoResources;

  /// Heading of the collapsible MCP resource template list.
  ///
  /// In en, this message translates to:
  /// **'Resource templates'**
  String get mcpSettingsResourceTemplates;

  /// Empty state of the MCP resource template list.
  ///
  /// In en, this message translates to:
  /// **'This server publishes no resource templates.'**
  String get mcpSettingsNoResourceTemplates;

  /// Heading of the discovered tool list.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get mcpSettingsDiscoveredTools;

  /// Shown when a ready server has no tools.
  ///
  /// In en, this message translates to:
  /// **'This server publishes no tools.'**
  String get mcpSettingsNoTools;

  /// Heading of the retained server diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Server output'**
  String get mcpSettingsDiagnostics;

  /// Label of the secret dialog action.
  ///
  /// In en, this message translates to:
  /// **'Store a secret'**
  String get mcpSettingsSecretSet;

  /// Label of the secret key field.
  ///
  /// In en, this message translates to:
  /// **'Reference name'**
  String get mcpSettingsSecretKey;

  /// Label of the secret value field.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get mcpSettingsSecretValue;

  /// Label of the composer context budget meter.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get sessionContextMeter;

  /// Accessible value of the context budget meter.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the context window used'**
  String sessionContextMeterValue(int percent);

  /// No description provided for @sessionContextDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Context usage'**
  String get sessionContextDetailsTitle;

  /// No description provided for @sessionContextPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String sessionContextPercent(int percent);

  /// No description provided for @sessionContextTokens.
  ///
  /// In en, this message translates to:
  /// **'{used} / {max} tokens'**
  String sessionContextTokens(String used, String max);

  /// No description provided for @sessionContextCost.
  ///
  /// In en, this message translates to:
  /// **'Session cost {cost}'**
  String sessionContextCost(String cost);

  /// No description provided for @sessionQuotaLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading provider usage'**
  String get sessionQuotaLoading;

  /// No description provided for @sessionQuotaError.
  ///
  /// In en, this message translates to:
  /// **'Provider usage is temporarily unavailable.'**
  String get sessionQuotaError;

  /// No description provided for @sessionQuotaProviderPlan.
  ///
  /// In en, this message translates to:
  /// **'{provider} · {plan}'**
  String sessionQuotaProviderPlan(String provider, String plan);

  /// No description provided for @sessionQuotaPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String sessionQuotaPercent(int percent);

  /// No description provided for @sessionQuotaResets.
  ///
  /// In en, this message translates to:
  /// **'Resets {time}'**
  String sessionQuotaResets(String time);

  /// No description provided for @sessionQuotaCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits {amount}'**
  String sessionQuotaCredits(String amount);

  /// No description provided for @sessionQuotaWindowSession.
  ///
  /// In en, this message translates to:
  /// **'Session limit'**
  String get sessionQuotaWindowSession;

  /// No description provided for @sessionQuotaWindowWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit'**
  String get sessionQuotaWindowWeekly;

  /// No description provided for @sessionQuotaWindowCodeReview.
  ///
  /// In en, this message translates to:
  /// **'Code review limit'**
  String get sessionQuotaWindowCodeReview;

  /// Error shown when a slash command is submitted with attachments.
  ///
  /// In en, this message translates to:
  /// **'Remove attachments to run a command.'**
  String get composerCommandNoAttachments;

  /// Empty state of the composer command list.
  ///
  /// In en, this message translates to:
  /// **'No commands'**
  String get composerCommandsEmpty;

  /// Empty state of the composer file mention list.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get composerFilesEmpty;

  /// Loading state of the composer file mention list.
  ///
  /// In en, this message translates to:
  /// **'Searching workspace'**
  String get composerFilesSearching;

  /// Error state of the composer command list.
  ///
  /// In en, this message translates to:
  /// **'Could not load commands'**
  String get composerCommandsError;

  /// Error state of the composer file mention list.
  ///
  /// In en, this message translates to:
  /// **'Could not search files'**
  String get composerFilesError;

  /// Badge marking an app-owned composer command.
  ///
  /// In en, this message translates to:
  /// **'app'**
  String get composerCommandSourceClient;

  /// Badge marking a Markdown-defined agent command.
  ///
  /// In en, this message translates to:
  /// **'command'**
  String get composerCommandSourceAgent;

  /// Badge marking a composer command that loads a skill.
  ///
  /// In en, this message translates to:
  /// **'skill'**
  String get composerCommandSourceSkill;

  /// Name of the composer command that clears the draft.
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get composerCommandClearLabel;

  /// Description of the clear command.
  ///
  /// In en, this message translates to:
  /// **'Clear the composer.'**
  String get composerCommandClearDescription;

  /// Name of the composer command that starts a session.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get composerCommandNewLabel;

  /// Description of the new session command.
  ///
  /// In en, this message translates to:
  /// **'Start a new session.'**
  String get composerCommandNewDescription;

  /// Name of the composer command that opens agent settings.
  ///
  /// In en, this message translates to:
  /// **'agents'**
  String get composerCommandAgentsLabel;

  /// Description of the agents command.
  ///
  /// In en, this message translates to:
  /// **'Open agent settings.'**
  String get composerCommandAgentsDescription;

  /// Name of the composer command that opens skill settings.
  ///
  /// In en, this message translates to:
  /// **'skills'**
  String get composerCommandSkillsLabel;

  /// Description of the skills command.
  ///
  /// In en, this message translates to:
  /// **'Open skill settings.'**
  String get composerCommandSkillsDescription;

  /// Name of the composer command that lists commands.
  ///
  /// In en, this message translates to:
  /// **'help'**
  String get composerCommandHelpLabel;

  /// Description of the help command.
  ///
  /// In en, this message translates to:
  /// **'List the available commands.'**
  String get composerCommandHelpDescription;

  /// Accessible name of the composer suggestion list.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get composerSuggestionsLabel;

  /// Instruction shown over a composer pane while files are dragged over it.
  ///
  /// In en, this message translates to:
  /// **'Drop files here'**
  String get composerDropFilesHere;

  /// No description provided for @chatToolActionRead.
  ///
  /// In en, this message translates to:
  /// **'Read file'**
  String get chatToolActionRead;

  /// No description provided for @chatToolActionList.
  ///
  /// In en, this message translates to:
  /// **'List files'**
  String get chatToolActionList;

  /// No description provided for @chatToolActionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatToolActionSearch;

  /// No description provided for @chatToolActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit files'**
  String get chatToolActionEdit;

  /// No description provided for @chatToolActionRun.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get chatToolActionRun;

  /// No description provided for @chatToolActionDelegate.
  ///
  /// In en, this message translates to:
  /// **'Coordinate agents'**
  String get chatToolActionDelegate;

  /// No description provided for @chatToolActionAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get chatToolActionAsk;

  /// No description provided for @chatToolActionResource.
  ///
  /// In en, this message translates to:
  /// **'Use resource'**
  String get chatToolActionResource;

  /// No description provided for @chatToolActionTools.
  ///
  /// In en, this message translates to:
  /// **'Find tools'**
  String get chatToolActionTools;

  /// No description provided for @chatToolActionClock.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get chatToolActionClock;

  /// No description provided for @chatToolActionContext.
  ///
  /// In en, this message translates to:
  /// **'Manage context'**
  String get chatToolActionContext;

  /// No description provided for @chatToolActionImage.
  ///
  /// In en, this message translates to:
  /// **'View image'**
  String get chatToolActionImage;

  /// No description provided for @chatToolActionGeneric.
  ///
  /// In en, this message translates to:
  /// **'Use tool'**
  String get chatToolActionGeneric;

  /// Label of a live expandable reasoning row.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get chatReasoningThinking;

  /// Label of a completed expandable reasoning row.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get chatReasoningThought;

  /// Placeholder inside reasoning opened before text arrives.
  ///
  /// In en, this message translates to:
  /// **'Waiting for reasoning details…'**
  String get chatReasoningWaiting;

  /// No description provided for @chatToolStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get chatToolStatusFailed;

  /// No description provided for @chatToolStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get chatToolStatusDenied;

  /// No description provided for @chatToolDetailsTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get chatToolDetailsTool;

  /// No description provided for @chatToolDetailsRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get chatToolDetailsRequest;

  /// No description provided for @chatToolDetailsResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get chatToolDetailsResult;

  /// No description provided for @settingsCategoryPlugin.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get settingsCategoryPlugin;

  /// No description provided for @pluginSettingsHeading.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get pluginSettingsHeading;

  /// No description provided for @pluginSettingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} plugins'**
  String pluginSettingsCount(int count);

  /// No description provided for @pluginSettingsSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a plugin.'**
  String get pluginSettingsSelect;

  /// No description provided for @pluginSettingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Create plugin'**
  String get pluginSettingsAdd;

  /// No description provided for @pluginSettingsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Create plugin starter'**
  String get pluginSettingsAddTitle;

  /// No description provided for @pluginSettingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plugins are installed.'**
  String get pluginSettingsEmpty;

  /// No description provided for @pluginSettingsSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get pluginSettingsSource;

  /// No description provided for @pluginSettingsSourceBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get pluginSettingsSourceBuiltIn;

  /// No description provided for @pluginSettingsSourceUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get pluginSettingsSourceUser;

  /// No description provided for @pluginSettingsSourcePath.
  ///
  /// In en, this message translates to:
  /// **'Source path'**
  String get pluginSettingsSourcePath;

  /// No description provided for @pluginSettingsApi.
  ///
  /// In en, this message translates to:
  /// **'Plugin API'**
  String get pluginSettingsApi;

  /// No description provided for @pluginSettingsApiValue.
  ///
  /// In en, this message translates to:
  /// **'API {api}'**
  String pluginSettingsApiValue(int api);

  /// No description provided for @pluginSettingsRevision.
  ///
  /// In en, this message translates to:
  /// **'Active revision'**
  String get pluginSettingsRevision;

  /// No description provided for @pluginSettingsRevisionMissing.
  ///
  /// In en, this message translates to:
  /// **'No active revision'**
  String get pluginSettingsRevisionMissing;

  /// No description provided for @pluginSettingsStale.
  ///
  /// In en, this message translates to:
  /// **'Using last known good revision'**
  String get pluginSettingsStale;

  /// No description provided for @pluginSettingsAuthoring.
  ///
  /// In en, this message translates to:
  /// **'Lua development environment'**
  String get pluginSettingsAuthoring;

  /// No description provided for @pluginSettingsAuthoringStatus.
  ///
  /// In en, this message translates to:
  /// **'Authoring status'**
  String get pluginSettingsAuthoringStatus;

  /// No description provided for @pluginSettingsAuthoringSynchronized.
  ///
  /// In en, this message translates to:
  /// **'Synchronized'**
  String get pluginSettingsAuthoringSynchronized;

  /// No description provided for @pluginSettingsAuthoringNeedsSync.
  ///
  /// In en, this message translates to:
  /// **'Synchronization required'**
  String get pluginSettingsAuthoringNeedsSync;

  /// No description provided for @pluginSettingsSdkAbi.
  ///
  /// In en, this message translates to:
  /// **'SDK ABI'**
  String get pluginSettingsSdkAbi;

  /// No description provided for @pluginSettingsLuaRuntime.
  ///
  /// In en, this message translates to:
  /// **'Lua runtime'**
  String get pluginSettingsLuaRuntime;

  /// No description provided for @pluginSettingsLuaLs.
  ///
  /// In en, this message translates to:
  /// **'Lua Language Server'**
  String get pluginSettingsLuaLs;

  /// No description provided for @pluginSettingsLuaConfig.
  ///
  /// In en, this message translates to:
  /// **'LuaLS configuration'**
  String get pluginSettingsLuaConfig;

  /// No description provided for @pluginSettingsSdkSync.
  ///
  /// In en, this message translates to:
  /// **'Synchronize SDK'**
  String get pluginSettingsSdkSync;

  /// No description provided for @pluginSettingsCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Requested capabilities'**
  String get pluginSettingsCapabilities;

  /// No description provided for @pluginSettingsCapabilitiesNone.
  ///
  /// In en, this message translates to:
  /// **'No host capabilities requested.'**
  String get pluginSettingsCapabilitiesNone;

  /// No description provided for @pluginSettingsAgents.
  ///
  /// In en, this message translates to:
  /// **'Referencing agents'**
  String get pluginSettingsAgents;

  /// No description provided for @pluginSettingsAgentsNone.
  ///
  /// In en, this message translates to:
  /// **'No Agent references this plugin.'**
  String get pluginSettingsAgentsNone;

  /// No description provided for @pluginSettingsContributions.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get pluginSettingsContributions;

  /// No description provided for @pluginSettingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get pluginSettingsDiagnostics;

  /// No description provided for @pluginSettingsDiagnosticsNone.
  ///
  /// In en, this message translates to:
  /// **'No diagnostics.'**
  String get pluginSettingsDiagnosticsNone;

  /// No description provided for @pluginSettingsValidate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get pluginSettingsValidate;

  /// No description provided for @pluginSettingsReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get pluginSettingsReload;

  /// No description provided for @pluginSettingsOpenPath.
  ///
  /// In en, this message translates to:
  /// **'Open plugin folder'**
  String get pluginSettingsOpenPath;

  /// No description provided for @pluginSettingsFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get pluginSettingsFork;

  /// No description provided for @pluginSettingsForkTitle.
  ///
  /// In en, this message translates to:
  /// **'Fork {plugin}'**
  String pluginSettingsForkTitle(String plugin);

  /// No description provided for @pluginSettingsForkDescription.
  ///
  /// In en, this message translates to:
  /// **'Copies the validated revision into a new app-data plugin without enabling it for any Agent.'**
  String get pluginSettingsForkDescription;

  /// No description provided for @pluginSettingsReloadAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent grants used for reload'**
  String get pluginSettingsReloadAgent;

  /// No description provided for @pluginSettingsReloadNeedsAgent.
  ///
  /// In en, this message translates to:
  /// **'Reference this plugin from an Agent before reloading it.'**
  String get pluginSettingsReloadNeedsAgent;

  /// No description provided for @pluginSettingsId.
  ///
  /// In en, this message translates to:
  /// **'Plugin ID'**
  String get pluginSettingsId;

  /// No description provided for @pluginSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pluginSettingsName;

  /// No description provided for @pluginSettingsIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a lowercase dot-separated namespace, such as example.tools.'**
  String get pluginSettingsIdInvalid;

  /// No description provided for @pluginSettingsIdTaken.
  ///
  /// In en, this message translates to:
  /// **'That plugin ID already exists.'**
  String get pluginSettingsIdTaken;

  /// No description provided for @pluginSettingsUi.
  ///
  /// In en, this message translates to:
  /// **'Plugin interface'**
  String get pluginSettingsUi;

  /// No description provided for @pluginUiLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading plugin interface'**
  String get pluginUiLoading;

  /// No description provided for @pluginUiLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The plugin interface could not be loaded.'**
  String get pluginUiLoadFailed;

  /// No description provided for @pluginUiInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsupported plugin interface'**
  String get pluginUiInvalidTitle;

  /// Explains the safe fallback for an invalid plugin UI document.
  ///
  /// In en, this message translates to:
  /// **'This document is invalid, so {appName} rendered its source as a read-only disclosure.'**
  String pluginUiInvalidDescription(String appName);

  /// No description provided for @pluginUiSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{plugin} plugin interface'**
  String pluginUiSemanticLabel(String plugin);

  /// No description provided for @pluginSessionControlLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading session control'**
  String get pluginSessionControlLoading;

  /// No description provided for @pluginSessionControlLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The plugin session control could not be loaded.'**
  String get pluginSessionControlLoadFailed;

  /// No description provided for @pluginSessionControlUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported plugin session control'**
  String get pluginSessionControlUnsupported;

  /// No description provided for @pluginSessionControlSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The plugin session control could not be saved.'**
  String get pluginSessionControlSaveFailed;

  /// No description provided for @pluginContributionDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get pluginContributionDriver;

  /// No description provided for @pluginContributionExtension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get pluginContributionExtension;

  /// No description provided for @pluginContributionTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get pluginContributionTool;

  /// No description provided for @pluginContributionSessionControl.
  ///
  /// In en, this message translates to:
  /// **'Session control'**
  String get pluginContributionSessionControl;

  /// No description provided for @pluginContributionUi.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get pluginContributionUi;

  /// No description provided for @pluginSettingsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Plugin action failed'**
  String get pluginSettingsActionFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
