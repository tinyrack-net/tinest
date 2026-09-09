import 'package:tinest_quality/src/feature_verifier.dart';

const Set<FeatureSurface> _desktop = <FeatureSurface>{FeatureSurface.desktop};
// Web reaches a daemon exactly the way mobile does, through the shared
// remote-only bootstrap, so every scenario mobile supports it supports too.
const Set<FeatureSurface> _allSurfaces = <FeatureSurface>{
  FeatureSurface.desktop,
  FeatureSurface.mobile,
  FeatureSurface.web,
};

const Set<FeatureVerificationLayer> _pluginFeatureLayers =
    <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    };

/// Complete traceability manifest for user-visible Tinest capabilities.
const List<FeatureContract> tinestFeatureManifest = <FeatureContract>[
  FeatureContract(
    id: 'soft.keyboard.visibility',
    description:
        'Keeps focused inputs and required actions above the software keyboard '
        'across pages, dialogs, drawers, settings forms, and terminals.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.platformSmoke,
    },
  ),
  FeatureContract(
    id: 'daemon.management',
    description: 'Starts, connects, edits, and removes daemon hosts.',
    apiMethods: <String>['close'],
    routes: <String>[
      'DaemonSettingsRoute',
      'AdvancedNewHostRoute',
      'EditHostRoute',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'remote_host_lifecycle',
        description: 'Adds, connects, edits, and removes a remote daemon.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'embedded_host_lifecycle',
        description: 'Starts and stops the app-owned embedded daemon.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'connection_failure_recovery',
        description: 'Shows a failed host and reconnects after recovery.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'daemon.authentication',
    description:
        'Uses one bearer token for complete local and remote daemon access.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'valid_token_reconnect',
        description: 'Authenticates and reconnects with the persisted token.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'invalid_token_rejected',
        description: 'Rejects an invalid token without exposing daemon data.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'daemon.exposure',
    description:
        'Configures and restarts the embedded daemon listener address and '
        'port.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'loopback_lan_restart',
        description: 'Restarts the embedded daemon across exposure modes.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'restart_failure_recovery',
        description: 'Reports a restart failure and keeps a recoverable host.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'port_change_restart',
        description: 'Applies a new listener port and reconnects the daemon.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'daemon.relay',
    description:
        'Pairs daemon-scoped devices over an end-to-end encrypted relay and '
        'fails over between direct and relay paths.',
    apiMethods: <String>[
      'relay.getRelayStatus',
      'relay.setRelayEnabled',
      'relay.setRelayEndpoint',
      'relay.createRelayPairingOffer',
      'relay.listRelayDevices',
      'relay.revokeRelayDevice',
    ],
    routes: <String>[
      'ConnectDaemonRoute',
      'PairingLinkRoute',
      'PairingScanRoute',
      'PairOfferRoute',
      'DaemonConnectionsRoute',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'pairing',
        description:
            'Pairs with a ten-minute link and reconnects by device key.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'failover',
        description:
            'Keeps daemon identity and RPC state across path failover.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'revocation',
        description: 'Revokes a device and ends its live encrypted session.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'relay_attachment',
        description: 'Streams a large attachment through bounded relay credit.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'settings.async.loading',
    description:
        'Keeps settings navigation usable while asynchronous reads show '
        'shape-preserving skeletons, transition to loaded content, or surface '
        'failures with an explicit Retry action.',
    requiredLayers: <FeatureVerificationLayer>{FeatureVerificationLayer.widget},
  ),
  FeatureContract(
    id: 'workspace.async.loading',
    description:
        'Keeps workspace navigation and interactions responsive while '
        'asynchronous reads show shape-preserving skeletons and optimistic '
        'placeholders that transition to loaded content.',
    requiredLayers: <FeatureVerificationLayer>{FeatureVerificationLayer.widget},
  ),
  FeatureContract(
    id: 'settings.reset',
    description:
        'Erases embedded daemon data and every device-local app setting '
        'while preserving managed Git checkouts, then restarts the '
        'app-owned daemon.',
    routes: <String>['AdvancedSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'full_reset_restart',
        description:
            'Erases daemon data and app settings, then reconnects a daemon '
            'with a new server identity.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'preserves_checkouts',
        description: 'Keeps managed Git checkouts after a full reset.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'workspace.catalog',
    description: 'Merges repositories and worktrees from every online host.',
    apiMethods: <String>[
      'workspaces.getWorkspaceCatalog',
      'workspaces.refreshWorkspace',
    ],
    routes: <String>['WorkspaceHomeRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'multi_host_merge_refresh',
        description: 'Merges and refreshes workspaces from online hosts.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'empty_offline_recovery',
        description: 'Presents empty and offline states and recovers.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'workspace.registration',
    description: 'Selects a daemon path and registers or removes a repository.',
    apiMethods: <String>[
      'workspaces.registerWorkspace',
      'workspaces.unregisterWorkspace',
      'workspaces.suggestDirectories',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'browse_register_unregister',
        description: 'Browses a daemon path and registers then removes it.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'invalid_path_cancel',
        description: 'Rejects invalid paths and preserves state on cancel.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'settings.language',
    description:
        'Selects the app UI language or follows the system locale, and keeps '
        'the choice across restarts.',
    routes: <String>['GeneralSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'selection_restart_persistence',
        description: 'Changes locale and preserves it across app restart.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'system_locale_fallback',
        description: 'Follows supported and unsupported system locales.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'settings.appearance',
    description:
        'Selects the light or dark app theme or follows the system '
        'brightness, and keeps the choice across restarts.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'restart_persistence',
        description: 'Changes the theme and preserves it across app restart.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'system_brightness_follow',
        description:
            'Tracks the platform brightness while following the system.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'app.navigation',
    description:
        'Uses typed Settings and Workspace shell routes with Material Page and '
        'Navigator lifecycle across one-, two-, and three-pane layouts. System '
        'Back follows concrete history, Up follows the logical hierarchy, and '
        'lateral settings or workspace replacements preserve stable shell '
        'state without app-owned animation or pane-history synchronization.',
    routes: <String>['SettingsHomeRoute', 'DaemonCategoriesRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'app.toast',
    description:
        'Reports the outcome of a user action as a transient notification: '
        'every failure, and the successes whose result the screen does not '
        'otherwise show. Survives the screen that started the action closing, '
        'and describes a failure without leaking the exception that caused it.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'settings.startup',
    description:
        'Registers the app with the operating system login items and chooses '
        'whether a login-time launch starts hidden in the tray.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'registration_toggle',
        description: 'Enables and disables operating-system login startup.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'hidden_login_launch',
        description: 'Starts a login-time launch hidden without window flash.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'desktop.residency',
    description:
        'Keeps the desktop app and its embedded daemon resident in the tray '
        'when the window is closed, reports daemon health without unbounded '
        'failure details, and quits only from the tray menu.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'close_hide_restore',
        description: 'Hides on close and restores from the resident process.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'tray_quit',
        description: 'Quits only through the tray quit action.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'desktop.window.chrome',
    description:
        'Replaces Windows and Linux native title bars with localized menus, '
        'window controls, and a draggable application frame.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'localized_menu_navigation',
        description: 'Navigates through the localized desktop menu.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'native_window_controls',
        description: 'Uses minimize, maximize, restore, and close controls.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'project.settings',
    description:
        'Edits per-project worktree lifecycle hooks stored in the repository '
        "root's .tinest/config.json.",
    apiMethods: <String>[
      'workspaces.getProjectSettings',
      'workspaces.saveProjectSettings',
    ],
    routes: <String>['ProjectSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'load_save_persist_hooks',
        description: 'Loads, saves, and reloads project lifecycle hooks.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'hook_failure_feedback',
        description: 'Reports invalid hook settings and recovers after repair.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'worktree.lifecycle',
    description:
        'Creates and safely archives Git worktrees, running the project '
        'setup and teardown hooks around each checkout.',
    apiMethods: <String>[
      'workspaces.listGitBranches',
      'workspaces.createWorktree',
      'workspaces.previewWorktreeArchive',
      'workspaces.archiveWorktree',
    ],
    routes: <String>['WorktreeRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'create_and_archive',
        description: 'Creates and safely archives a managed worktree.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'setup_failure_cleanup',
        description: 'Cleans up a checkout after setup hook failure.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'archive_preview_cancel',
        description: 'Previews archive effects and preserves on cancel.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'archive_external',
        description:
            'Archives a discovered external worktree and removes its checkout.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'permission.settings',
    description:
        'Stores one daemon-global permission default and presents localized '
        'permission behavior for agents and sessions that inherit it.',
    apiMethods: <String>[
      'agents.getDefaultPermissionMode',
      'agents.setDefaultPermissionMode',
    ],
    routes: <String>['PermissionSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'session.lifecycle',
    description:
        'Starts sessions from the chat composer with a selected Agent and '
        'model, resolves the model provider automatically, and atomically '
        'changes the model, dynamic model controls, or permission mode.',
    apiMethods: <String>[
      'sessions.listSessions',
      'sessions.createSession',
      'sessions.updateSettings',
    ],
    routes: <String>['SessionRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'create_with_configuration',
        description: 'Creates a session with a chosen Agent and model.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'update_model_and_controls',
        description: 'Changes model and model controls after creation.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'reconnect_persistence',
        description: 'Restores session configuration after reconnect.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'session.plan',
    description:
        'Uses the tinest.plan Lua extension to expose an Agent-selected, '
        'durable session-scoped control, contribute the exact Plan prompt, '
        'restrictions, '
        'atomically replace plans, and render historical plan snapshots.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'session.goal',
    description:
        'Uses the tinest.goal Lua extension to persist a session-scoped '
        'objective, account usage, schedule serialized continuations, and '
        'publish goal status and actions through declarative plugin UI.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'multi_turn_completion_reconnect',
        description:
            'Creates a goal, completes deterministic continuation turns, and '
            'restores the completed goal after reconnect.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'session.home',
    description:
        'Starts a session without picking a project. The daemon provisions the '
        'user home directory as an implicit home workspace that no project '
        'list offers and that clients cannot unregister or archive, and the '
        'sidebar lists these sessions outside every project.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'create_without_project',
        description:
            'Creates a session with no project and runs it in the home folder.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'session.tabs',
    description:
        'Opens, closes, restores, and moves tabs through resizable desktop '
        'pane trees and a horizontally scrolling mobile tab strip.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'open_switch_close_restore',
        description:
            'Splits, resizes, moves, closes, restores, and switches tabs '
            'through desktop panes and the mobile tab strip.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'terminal.lifecycle',
    description:
        'Creates, attaches, resizes, and terminates daemon-owned interactive '
        'terminal tabs with standard keyboard and pointer input, and restores '
        'a reattaching client from the screen the daemon holds, so a running '
        'full-screen program comes back as it was left.',
    apiMethods: <String>[
      'terminals.listTerminals',
      'terminals.createTerminal',
      'terminals.attachTerminal',
      'terminals.writeTerminal',
      'terminals.resizeTerminal',
      'terminals.terminateTerminal',
    ],
    routes: <String>['TerminalRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'create_write_terminate',
        description:
            'Creates a real PTY, writes and observes output, then terminates '
            'it.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'keyboard_context_menu_input',
        description:
            'Restores input after native-menu selection and cancellation, '
            'edits across an automatically wrapped row, commits repeated '
            'Hangul jamo one keystroke at a time, and renders real IME '
            'preedit before continuing committed keyboard input, including '
            'the Control+Shift+C/V clipboard chords.',
        surfaces: _desktop,
      ),
      FeatureScenario(
        id: 'mobile_software_keyboard_input',
        description:
            'Restores the focused terminal input connection on mobile and '
            'forwards Korean text and Enter to the daemon without loss, '
            'duplication, or line-ending drift.',
        surfaces: <FeatureSurface>{FeatureSurface.mobile},
      ),
    ],
  ),
  FeatureContract(
    id: 'terminal.settings',
    description:
        'Resolves and edits project and daemon-host shell configuration.',
    apiMethods: <String>[
      'terminals.getTerminalShell',
      'terminals.setTerminalShell',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'turn.execution',
    description:
        'Streams visible reasoning and responses, cancels, approves, rejects, '
        'and restores turns.',
    apiMethods: <String>[
      'sessions.startTurn',
      'sessions.cancelTurn',
      'sessions.resolveApproval',
      'sessions.subscribeTimeline',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'stream_and_restore',
        description: 'Streams a completed turn and restores its timeline.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'cancel_stream',
        description: 'Cancels an active stream and records cancellation.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'approve_and_reject',
        description: 'Approves and rejects tool requests with durable results.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'provider_failure_recovery',
        description: 'Shows provider failure and accepts a later retry.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'conversation.turn.queue',
    description:
        'Queues prompts typed during a turn, starts them as it finishes, and '
        'tells the daemon so a sleeping agent wakes early.',
    apiMethods: <String>['sessions.notePendingInput'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'conversation.history.pagination',
    description:
        'Opens a conversation on its newest page and loads earlier messages '
        'as the reader scrolls back, so history never arrives as one frame. A '
        'page extends the row it belongs to rather than replacing it, and a '
        'page that failed waits for the reader to ask again.',
    apiMethods: <String>['sessions.readTimelineHistory'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'page_back',
        description:
            'Opens a conversation longer than one page at its newest message, '
            'drags back to load earlier pages, and reopens where the reader '
            'left it.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'turn.question',
    description:
        'Blocks a turn on a structured agent question and records the user '
        'answer, including free-form input.',
    apiMethods: <String>['sessions.answerUserQuestion'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'ask_and_answer',
        description: 'Answers a blocking agent question and resumes the turn.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'tool.harness.parity',
    description:
        'Pins the modern Codex v2 tool contract, distinguishes Tinest '
        'extensions and exclusions, and verifies typed wire declarations.',
    requiredLayers: <FeatureVerificationLayer>{FeatureVerificationLayer.unit},
  ),
  FeatureContract(
    id: 'tool.exec.session',
    description:
        'Runs and drives command sessions inside a turn, on plain pipes or a '
        'pseudo-terminal, in a chosen workspace directory, with scoped session '
        'lifetime and per-session approval.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'tool.clock',
    description:
        'Reports the current UTC time and pauses a turn, ending the pause '
        'early when the user queues new input.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'lua.tool.orchestration',
    description:
        'Runs sandboxed Lua cells that orchestrate selected tools through the '
        'ordinary approval, cancellation, media, and session lifecycle.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.platformSmoke,
    },
  ),
  FeatureContract(
    id: 'tool.search.deferred',
    description:
        'Withholds bulk tools from the model tool list and makes them '
        'callable through a search that persists across a session.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'mcp.resource.access',
    description:
        'Discovers MCP resources and templates, shows them per server, and '
        'reads one resource inside a turn.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'context.compaction',
    description:
        'Lets the selected Lua Agent driver summarize and replace its durable '
        'model history when its token budget is spent, a context tool asks, '
        'or a provider refuses the history as too long.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'tool.context.budget',
    description:
        'Exposes the selected model window and normalized turn usage to an '
        'individually selectable Lua tool, and lets a driver start a fresh '
        'durable provider context on request.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'tool.search',
    description:
        'Searches workspace file contents by literal or regular expression and '
        'finds files by glob, honouring the same ignore rules as git.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'tool.image.context',
    description:
        'Loads a workspace image into the model conversation context and '
        'encodes it for the Responses and Chat Completions APIs.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'conversation.attachments',
    description:
        'Uploads, sends, previews, exports, and restores user and agent files.',
    apiMethods: <String>[
      'attachments.uploadAttachment',
      'attachments.downloadAttachment',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
      FeatureVerificationLayer.platformSmoke,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'picker_cancel_retry',
        description: 'Cancels file selection and retries without losing input.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'upload_preview_restore',
        description: 'Uploads ordered files, previews them, and restores them.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'agent_publish_download',
        description: 'Publishes and downloads an agent-created attachment.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'agent.definition.management',
    description:
        'Creates, validates, edits, archives, and resets Markdown Agents.',
    apiMethods: <String>[
      'agents.listAgentDefinitions',
      'agents.getAgentDefinition',
      'agents.createAgentDefinition',
      'agents.updateAgentDefinition',
      'agents.archiveAgentDefinition',
      'agents.resetAgentDefinition',
      'agents.validateAgentDefinition',
      'agents.listAgentTools',
    ],
    routes: <String>['AgentSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'create_validate_edit_reload',
        description: 'Creates, validates, edits, and reloads an Agent file.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'invalid_definition_rejected',
        description: 'Rejects invalid Markdown without overwriting the Agent.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'archive_and_reset',
        description: 'Archives a custom Agent and resets a built-in Agent.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'agent.harness',
    description:
        'Treats each version 5 Agent definition as the complete model harness '
        'with exactly one driver, ordered extensions, independently selected '
        'tools, plugin settings, callable Agents, and prompt data.',
    requiredLayers: _pluginFeatureLayers,
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'custom_driver_zero_tools_restart',
        description:
            'Runs and restores an Agent whose custom driver exposes no tools.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'incompatible_model_blocked',
        description:
            'Blocks a selected model that lacks the Agent driver requirements.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'plugin.management',
    description:
        'Lists, validates, reloads, and scaffolds built-in and app-data Lua '
        'plugins without a global activation switch.',
    apiMethods: <String>[
      'plugins.listPlugins',
      'plugins.getPlugin',
      'plugins.validatePlugin',
      'plugins.reloadPlugin',
      'plugins.scaffoldPlugin',
      'plugins.forkPlugin',
    ],
    routes: <String>['PluginSettingsRoute'],
    requiredLayers: _pluginFeatureLayers,
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'scaffold_detect_reload_lkg_restart',
        description:
            'Scaffolds a plugin, retains its LKG after an invalid reload, '
            'repairs it, and restores it after restart.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'plugin.runtime',
    description:
        'Loads immutable Lua and Markdown bundles, pins revisions per turn, '
        'and provides scoped state and durable serialized handler jobs.',
    apiMethods: <String>[
      'plugins.getPluginSessionControl',
      'plugins.setPluginSessionControl',
    ],
    requiredLayers: _pluginFeatureLayers,
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'user_tool_state_and_continuation',
        description:
            'Runs an app-data tool, persists scoped state, and resumes a '
            'scheduled handler after daemon restart.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'plugin.authoring',
    description:
        'Publishes the exact runtime SDK ABI as editor-neutral LuaCATS files, '
        'synchronizes sandboxed LuaLS configuration, and exposes CLI health '
        'and type-checking workflows.',
    apiMethods: <String>[
      'plugins.getPluginAuthoringEnvironment',
      'plugins.syncPluginAuthoringEnvironment',
    ],
    requiredLayers: _pluginFeatureLayers,
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'scaffold_sdk_sync_reload_restart',
        description:
            'Scaffolds an app-data plugin, synchronizes its exact SDK ABI, '
            'reloads it, and restores the revision after daemon restart.',
        surfaces: _desktop,
      ),
    ],
  ),
  FeatureContract(
    id: 'plugin.permissions',
    description:
        'Stores capability grants per Agent and plugin, enforces the core '
        'capability broker, and cancels a live primitive after revocation.',
    apiMethods: <String>[
      'plugins.listPluginGrants',
      'plugins.grantPluginCapability',
      'plugins.revokePluginCapability',
      'plugins.setPluginSecret',
      'plugins.removePluginSecret',
    ],
    requiredLayers: _pluginFeatureLayers,
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'agent_grant_revoke_live_primitive',
        description:
            'Grants one Agent a capability, keeps another Agent isolated, '
            'and revokes an active host primitive.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'plugin.ui',
    description:
        'Renders allowlisted declarative plugin documents with host-owned '
        'chrome, accessibility, action dispatch, fallback, and snapshots.',
    apiMethods: <String>[
      'plugins.renderPluginUi',
      'plugins.dispatchPluginUiAction',
    ],
    requiredLayers: _pluginFeatureLayers,
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'render_action_invalid_fallback_history',
        description:
            'Renders a plugin surface, dispatches an action, falls back for '
            'invalid UI, and restores its historical snapshot.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'mcp.server.management',
    description:
        'Adds, edits, tests, and removes external MCP servers and shows '
        'their connection status and discovered tools.',
    apiMethods: <String>[
      'mcp.listMcpServers',
      'mcp.addMcpServer',
      'mcp.updateMcpServer',
      'mcp.removeMcpServer',
      'mcp.testMcpServer',
      'mcp.setMcpSecret',
    ],
    routes: <String>['McpSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'add_edit_test_remove',
        description: 'Adds, edits, tests, and removes an MCP server.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'offline_and_secret_recovery',
        description: 'Shows offline state and reconnects with a stored secret.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'mcp.tool.execution',
    description:
        'Executes namespaced MCP tools inside a turn with approval, and '
        'degrades safely when a server is offline.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'approve_execute_result',
        description: 'Approves a namespaced tool and renders its result.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'reject_and_offline',
        description: 'Rejects execution and degrades safely when offline.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'skill.catalog',
    description:
        'Lists the effective read-only skill catalog for global and project '
        'scopes.',
    apiMethods: <String>['prompts.listSkills'],
    routes: <String>['SkillSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'global_project_partition',
        description:
            'Separates effective global skills from project-defined skills.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'external_file_refresh',
        description:
            'Refreshes the effective catalog after external file changes.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'skill.invocation',
    description:
        'Injects the effective skill catalog into a turn and loads skill '
        'instructions through the skill tool.',
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'effective_catalog_load',
        description: 'Injects effective skills and loads their instructions.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'shadowed_invalid_excluded',
        description: 'Excludes shadowed and invalid skills from the catalog.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'composer.file.mention',
    description:
        'Completes gitignore-aware worktree file paths from an @ token in the '
        'composer and inserts them into the prompt.',
    apiMethods: <String>['workspaces.searchFiles'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'mention_insert_path',
        description: 'Completes an @ token into a worktree-relative path.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'no_match_dismiss',
        description: 'Dismisses the mention list and sends the typed text.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'composer.slash.command',
    description:
        'Completes client, skill, and agent commands from a / token and either '
        'runs the app action or expands the prompt.',
    apiMethods: <String>['prompts.listCommands'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'client_command_dispatch',
        description: 'Runs an app-owned command without starting a turn.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'agent_command_prompt',
        description: 'Expands an agent command template into the prompt.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'agent.collaboration',
    description:
        'Spawns, messages, waits on, interrupts, and lists collaborating '
        'subagent sessions, and exposes them through the collaboration '
        "plugin's composer drawer.",
    apiMethods: <String>['sessions.listSubagents'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'spawn_child_final_answer',
        description:
            'Spawns a subagent asynchronously, answers its approval from the '
            'subagent tab, and wakes the idle parent with its final answer.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'unauthorized_agent_type_rejected',
        description: 'Rejects a spawn outside the caller agent allowlist.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'provider.catalog',
    description:
        'Lists bundled, cached, and refreshed provider models, streams '
        'background catalog state, and keeps offline fallback metadata.',
    apiMethods: <String>[
      'providers.listProviderCatalog',
      'providers.listProviderConnections',
      'providers.refreshProviderCatalog',
      'providers.listProviderModels',
    ],
    routes: <String>['ProviderSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'presets_models_refresh',
        description: 'Lists presets and refreshes available model catalogs.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'catalog_failure_retry',
        description: 'Shows catalog failure and succeeds on retry.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'provider.usage',
    description:
        'Lazily reads safe subscription quota for Tinest-managed provider '
        'connections and presents it with context and session cost.',
    apiMethods: <String>['providers.listProviderUsage'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'context_usage_hover',
        description: 'Opens the compact context ring and shows provider quota.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'model.settings',
    description:
        'Owns one concrete daemon default model and resolves new sessions from '
        'the chat override, agent model, then daemon default.',
    apiMethods: <String>['models.getSettings', 'models.setDefaultModel'],
    routes: <String>['ModelSettingsRoute'],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
    },
  ),
  FeatureContract(
    id: 'provider.connection.management',
    description:
        'Connects, reconnects in place, and disconnects OpenAI, Anthropic, '
        'Gemini, and compatible provider presets through their public API '
        'contracts.',
    apiMethods: <String>[
      'providers.connectProviderApiKey',
      'providers.connectProviderNone',
      'providers.disconnectProvider',
      'providers.updateProviderModelPrefix',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'api_key_none_disconnect',
        description: 'Connects supported credential modes and disconnects.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'invalid_credential_recovery',
        description: 'Reports invalid credentials and accepts a correction.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'provider.oauth',
    description:
        'Starts, observes, cancels, retries, and uses supported public '
        'provider OAuth flows to create or reauthenticate a connection '
        'without subscription-only private endpoints.',
    apiMethods: <String>[
      'providers.startProviderAuth',
      'providers.providerAuthStatus',
      'providers.cancelProviderAuth',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'authorize_and_refresh',
        description: 'Completes OAuth and refreshes the connected catalog.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'cancel_and_error_recovery',
        description: 'Cancels OAuth and recovers from authorization failure.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
  FeatureContract(
    id: 'provider.custom',
    description:
        'Creates and edits compatible providers for OpenAI, Anthropic, and '
        'Gemini with typed manual models and wire-owned controls.',
    apiMethods: <String>[
      'providers.createCustomProvider',
      'providers.updateCustomProvider',
      'providers.deleteCustomProvider',
    ],
    requiredLayers: <FeatureVerificationLayer>{
      FeatureVerificationLayer.unit,
      FeatureVerificationLayer.contract,
      FeatureVerificationLayer.verticalSlice,
      FeatureVerificationLayer.widget,
      FeatureVerificationLayer.e2e,
    },
    e2eScenarios: <FeatureScenario>[
      FeatureScenario(
        id: 'create_edit_delete',
        description: 'Creates, edits, reloads, and deletes a custom provider.',
        surfaces: _allSurfaces,
      ),
      FeatureScenario(
        id: 'validation_and_model_failure',
        description: 'Rejects invalid configuration and reports model failure.',
        surfaces: _allSurfaces,
      ),
    ],
  ),
];

const List<UiStateContract> _renderedRouteState = <UiStateContract>[
  UiStateContract(
    id: 'rendered',
    description: 'The typed route renders its primary content without errors.',
  ),
];

const List<UiVariantContract> _routeViewportVariant = <UiVariantContract>[
  UiVariantContract(
    id: 'desktop_mobile_light_korean',
    description:
        'Light Korean UI renders at 1200x900 desktop, 800x900 tablet, and '
        '390x760 mobile sizes.',
  ),
];

const List<({String id, String featureId, String description})>
_uiRouteRegistrations = <({String id, String featureId, String description})>[
  (
    id: 'workspace_home_route',
    featureId: 'workspace.catalog',
    description: 'Workspace catalog home.',
  ),
  (
    id: 'worktree_route',
    featureId: 'worktree.lifecycle',
    description: 'Selected worktree and tab workspace.',
  ),
  (
    id: 'session_route',
    featureId: 'session.lifecycle',
    description: 'Conversation session timeline and composer.',
  ),
  (
    id: 'terminal_route',
    featureId: 'terminal.lifecycle',
    description: 'Attached daemon terminal.',
  ),
  (
    id: 'settings_home_route',
    featureId: 'app.navigation',
    description: 'Settings category home.',
  ),
  (
    id: 'daemon_categories_route',
    featureId: 'app.navigation',
    description: 'Daemon-scoped settings categories.',
  ),
  (
    id: 'general_settings_route',
    featureId: 'settings.language',
    description: 'Language, appearance, and startup settings.',
  ),
  (
    id: 'provider_settings_route',
    featureId: 'provider.catalog',
    description: 'Provider connections and models.',
  ),
  (
    id: 'model_settings_route',
    featureId: 'model.settings',
    description: 'Daemon default model settings.',
  ),
  (
    id: 'permission_settings_route',
    featureId: 'permission.settings',
    description: 'Daemon permission defaults.',
  ),
  (
    id: 'project_settings_route',
    featureId: 'project.settings',
    description: 'Registered project settings.',
  ),
  (
    id: 'agent_settings_route',
    featureId: 'agent.definition.management',
    description: 'Agent definition management.',
  ),
  (
    id: 'plugin_settings_route',
    featureId: 'plugin.management',
    description: 'Installed plugin revisions, diagnostics, and authoring.',
  ),
  (
    id: 'mcp_settings_route',
    featureId: 'mcp.server.management',
    description: 'MCP server management.',
  ),
  (
    id: 'skill_settings_route',
    featureId: 'skill.catalog',
    description: 'Read-only effective skill catalog.',
  ),
  (
    id: 'daemon_settings_route',
    featureId: 'daemon.management',
    description: 'Daemon host registry.',
  ),
  (
    id: 'advanced_settings_route',
    featureId: 'settings.reset',
    description: 'Advanced settings and full reset.',
  ),
  (
    id: 'connect_daemon_route',
    featureId: 'daemon.relay',
    description: 'Daemon connection entry point.',
  ),
  (
    id: 'pairing_link_route',
    featureId: 'daemon.relay',
    description: 'Relay pairing link entry.',
  ),
  (
    id: 'pairing_scan_route',
    featureId: 'daemon.relay',
    description: 'Relay pairing QR scan.',
  ),
  (
    id: 'pair_offer_route',
    featureId: 'daemon.relay',
    description: 'Relay pairing confirmation.',
  ),
  (
    id: 'advanced_new_host_route',
    featureId: 'daemon.management',
    description: 'Direct daemon host creation.',
  ),
  (
    id: 'daemon_connections_route',
    featureId: 'daemon.relay',
    description: 'Paired daemon device management.',
  ),
  (
    id: 'edit_host_route',
    featureId: 'daemon.management',
    description: 'Direct daemon host editing.',
  ),
];

/// Complete typed-route reachability catalog.
final List<UiReachabilityContract>
tinestUiReachabilityManifest = <UiReachabilityContract>[
  for (final route in _uiRouteRegistrations)
    UiReachabilityContract(
      id: route.id,
      featureId: route.featureId,
      description: route.description,
      states: _renderedRouteState,
      transitions: const <UiTransitionContract>[],
      variants: _routeViewportVariant,
    ),
  const UiReachabilityContract(
    id: 'conversation_timeline',
    featureId: 'turn.execution',
    description:
        'Conversation loading, streaming, queued work, blocking cards, '
        'errors, and recovery actions.',
    states: <UiStateContract>[
      UiStateContract(
        id: 'loading',
        description: 'Existing history is loading without a false empty state.',
      ),
      UiStateContract(
        id: 'empty',
        description: 'A loaded session with no history shows its empty state.',
      ),
      UiStateContract(
        id: 'streaming',
        description: 'Reasoning and response deltas remain visibly live.',
      ),
      UiStateContract(
        id: 'history_anchored',
        description:
            'Streaming and disclosure growth preserve the visible history '
            'anchor, and a conversation opens at its newest message unless '
            'the reader left it with messages below them.',
      ),
      UiStateContract(
        id: 'history_paging',
        description:
            'Reaching the oldest loaded message loads the page before it '
            'exactly once, without moving the reader.',
      ),
      UiStateContract(
        id: 'approval_pending',
        description: 'A tool approval remains actionable in the timeline.',
      ),
      UiStateContract(
        id: 'subagent_approval_pending',
        description:
            'A blocked descendant subagent is flagged on the parent and its '
            'approval stays actionable there.',
      ),
      UiStateContract(
        id: 'question_pending',
        description:
            'A structured question remains actionable in the timeline.',
      ),
      UiStateContract(
        id: 'queued_error',
        description: 'A drained prompt failure remains visible and actionable.',
      ),
    ],
    transitions: <UiTransitionContract>[
      UiTransitionContract(
        id: 'queue_prompt',
        description: 'Queues input typed while a turn is running.',
        fromState: 'streaming',
        outcomes: <String>{'streaming'},
      ),
      UiTransitionContract(
        id: 'retry_send',
        description: 'Restores a failed prompt and sends it successfully.',
        fromState: 'queued_error',
        outcomes: <String>{'empty', 'queued_error'},
      ),
      UiTransitionContract(
        id: 'cancel_turn',
        description: 'Stops a running turn without disabling later input.',
        fromState: 'streaming',
        outcomes: <String>{'empty', 'streaming'},
      ),
      UiTransitionContract(
        id: 'answer_question',
        description: 'Submits ordered option and free-form answers.',
        fromState: 'question_pending',
        outcomes: <String>{'streaming'},
      ),
    ],
    variants: <UiVariantContract>[
      UiVariantContract(
        id: 'desktop_light_korean_keyboard_online',
        description: 'Desktop light Korean keyboard input while online.',
      ),
      UiVariantContract(
        id: 'mobile_light_korean_large_text_touch_online',
        description: 'Narrow mobile light Korean layout with enlarged text.',
      ),
    ],
  ),
  const UiReachabilityContract(
    id: 'global_environment',
    featureId: 'app.navigation',
    description:
        'Application shell across theme, locale, viewport, text scale, '
        'and input-modality combinations.',
    states: <UiStateContract>[
      UiStateContract(
        id: 'offline_shell',
        description:
            'The application shell remains reachable without a daemon.',
      ),
    ],
    transitions: <UiTransitionContract>[],
    variants: <UiVariantContract>[
      UiVariantContract(
        id: 'desktop_dark_english_keyboard_offline',
        description: 'Desktop dark English keyboard path while offline.',
      ),
      UiVariantContract(
        id: 'mobile_light_japanese_touch_offline',
        description: 'Mobile light Japanese touch path while offline.',
      ),
      UiVariantContract(
        id: 'desktop_light_korean_large_text_pointer_offline',
        description:
            'Desktop light Korean large-text pointer path while offline.',
      ),
    ],
  ),
];

/// Composite conversation journeys which supplement atomic UI evidence.
const List<UiJourneyContract> tinestUiJourneyManifest = <UiJourneyContract>[
  UiJourneyContract(
    id: 'conversation_adversity',
    description:
        'Queues input, crosses approval and question boundaries, reconnects, '
        'and restores one durable timeline without duplication.',
    tier: UiEvidenceTier.prRequired,
    surfaces: <FeatureSurface>{FeatureSurface.desktop},
    transitionIds: <String>[
      'conversation_timeline/queue_prompt',
      'conversation_timeline/retry_send',
      'conversation_timeline/cancel_turn',
      'conversation_timeline/answer_question',
    ],
  ),
  UiJourneyContract(
    id: 'conversation_long_running',
    description:
        'Combines goal continuation, subagent work, attachments, compaction, '
        'provider recovery, and session switching.',
    tier: UiEvidenceTier.nightlyExtended,
    surfaces: <FeatureSurface>{FeatureSurface.desktop},
    transitionIds: <String>[
      'conversation_timeline/queue_prompt',
      'conversation_timeline/retry_send',
      'conversation_timeline/cancel_turn',
      'conversation_timeline/answer_question',
    ],
  ),
];
