import 'dart:async';
import 'dart:io';

import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/desktop/application/desktop_startup.dart';
import 'package:app/src/features/desktop/domain/tray_menu_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// How the application composes its desktop window chrome.
enum DesktopWindowChrome {
  /// The operating system owns both the window frame and application menus.
  native,

  /// Flutter owns the frame, application menus, and caption controls.
  custom;

  /// Whether Flutter renders the localized application menu row.
  bool get showsApplicationMenuBar => this == custom;

  /// Whether Flutter replaces the native title bar and caption controls.
  bool get usesCustomTitleBar => this == custom;
}

/// Controls the single desktop window from outside the widget tree.
abstract interface class DesktopWindow {
  /// Platform-specific ownership of the frame and application menus.
  DesktopWindowChrome get chrome;

  /// Current maximize state, including changes initiated by the OS.
  ValueListenable<bool> get maximized;

  /// Whether the window is on screen, including changes initiated by the OS.
  ///
  /// A hidden window makes the Linux and Windows embedders report
  /// `AppLifecycleState.hidden`, which disables frames, so anything that has to
  /// react to hiding must listen here rather than rebuild.
  ValueListenable<bool> get visible;

  /// Prepares the native window and decides whether it becomes visible.
  Future<void> prepare({required bool startHidden});

  /// Reveals and focuses the window.
  Future<void> show();

  /// Hides the window without ending the process.
  Future<void> hide();

  /// Whether the window is currently on screen.
  Future<bool> isVisible();

  /// Starts a native window move from the custom drag region.
  Future<void> startDragging();

  /// Minimizes the window to the platform task switcher.
  Future<void> minimize();

  /// Switches between maximized and restored bounds.
  Future<void> toggleMaximized();

  /// Routes the user's close gesture to [onClose] instead of quitting.
  Future<void> interceptClose(void Function() onClose);

  /// Stops intercepting so a later close really does end the process.
  Future<void> releaseClose();
}

/// Ends the host process once the app has torn itself down.
///
/// Quitting cannot be left to the native window teardown. On Windows
/// `windowManager.destroy` only posts `WM_QUIT`, and the runner then blocks in
/// its window destructor waiting for the Flutter engine and the Dart VM to
/// shut down, with the window still on screen and no message pump left to
/// service it. An embedded daemon isolate that has not finished exiting turns
/// that wait into a frozen, unkillable window.
abstract interface class AppTerminator {
  /// Ends the process immediately and successfully.
  Future<void> terminate();
}

/// Owns the platform tray, menu-bar, or notification-area icon.
abstract interface class TrayIcon {
  /// Creates the icon and menu, routing selections to [onSelected] by row key.
  ///
  /// [onActivated] runs when the user clicks the icon itself on the platforms
  /// where that gesture means "bring the app back".
  Future<void> install({
    required TrayMenuModel menu,
    required void Function(String itemKey) onSelected,
    required void Function() onActivated,
  });

  /// Replaces the menu and tooltip after a locale or daemon-state change.
  Future<void> update(TrayMenuModel menu);

  /// Removes the icon.
  Future<void> destroy();
}

/// Registers the app with the operating system's login-item mechanism.
abstract interface class AutostartRegistration {
  /// Rewrites the registration.
  ///
  /// [minimized] changes the recorded arguments, so turning it on or off has
  /// to re-register rather than only enable or disable.
  Future<void> apply({required bool enabled, required bool minimized});

  /// Whether the operating system currently launches the app at login.
  Future<bool> isEnabled();
}

/// Window control supplied by the desktop composition root.
///
/// Null means this platform has no window to manage, which is the honest
/// value for the mobile build rather than an error.
final desktopWindowProvider = Provider<DesktopWindow?>((ref) => null);

/// Tray icon supplied by the desktop composition root, or null on mobile.
final trayIconProvider = Provider<TrayIcon?>((ref) => null);

/// Login-item registration supplied by the desktop composition root.
final autostartProvider = Provider<AutostartRegistration?>((ref) => null);

/// Process terminator supplied by the desktop composition root.
///
/// Null means this build has no process of its own to end, which is the honest
/// value for the mobile and web builds rather than an error.
final appTerminatorProvider = Provider<AppTerminator?>((ref) => null);

/// Asset path of the tray icon for the current platform.
///
/// Windows renders only `.ico`, and macOS wants a monochrome template image
/// so the system can recolor it for light and dark menu bars.
String trayIconAssetPath({required TargetPlatform platform}) =>
    switch (platform) {
      TargetPlatform.windows => 'assets/tray/tray_icon.ico',
      TargetPlatform.macOS => 'assets/tray/tray_icon_template.png',
      _ => 'assets/tray/tray_icon.png',
    };

/// Production window adapter backed by `window_manager`.
final class PluginDesktopWindow implements DesktopWindow {
  /// Creates the production window adapter.
  new({
    TargetPlatform? platform,
    this.initialize = _ensureInitialized,
    this.configureCustomTitleBar = _configureCustomTitleBar,
    this.readyToShow = _waitUntilReadyToShow,
    this.showWindow = _showWindow,
    this.hideWindow = _hideWindow,
    this.windowIsVisible = _windowIsVisible,
    this.startWindowDrag = _startWindowDrag,
    this.minimizeWindow = _minimizeWindow,
    this.maximizeWindow = _maximizeWindow,
    this.unmaximizeWindow = _unmaximizeWindow,
    this.preventClose = _setPreventClose,
    this.addWindowListener = _addWindowListener,
    this.removeWindowListener = _removeWindowListener,
    this.waitForWindowState = _waitForWindowState,
  }) : platform = platform ?? defaultTargetPlatform;

  /// Platform used to select native or custom window chrome.
  final TargetPlatform platform;

  @override
  DesktopWindowChrome get chrome => switch (platform) {
    TargetPlatform.windows ||
    TargetPlatform.linux => DesktopWindowChrome.custom,
    _ => DesktopWindowChrome.native,
  };

  final ValueNotifier<bool> _maximized = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get maximized => _maximized;

  final ValueNotifier<bool> _visible = ValueNotifier<bool>(true);

  @override
  ValueListenable<bool> get visible => _visible;

  /// Injected `windowManager.ensureInitialized`.
  final Future<void> Function() initialize;

  /// Injected native title-bar configuration.
  final Future<void> Function({required bool enabled}) configureCustomTitleBar;

  /// Injected `windowManager.waitUntilReadyToShow`.
  final Future<void> Function(Future<void> Function()) readyToShow;

  /// Injected show-and-focus call.
  final Future<void> Function() showWindow;

  /// Injected hide call.
  final Future<void> Function() hideWindow;

  /// Injected visibility query.
  final Future<bool> Function() windowIsVisible;

  /// Injected native move operation.
  final Future<void> Function() startWindowDrag;

  /// Injected native minimize operation.
  final Future<void> Function() minimizeWindow;

  /// Injected native maximize operation.
  final Future<void> Function() maximizeWindow;

  /// Injected native restore-from-maximized operation.
  final Future<void> Function() unmaximizeWindow;

  /// Injected close-prevention toggle.
  final Future<void> Function({required bool prevent}) preventClose;

  /// Injected listener registration.
  final void Function(WindowListener) addWindowListener;

  /// Injected listener removal.
  final void Function(WindowListener) removeWindowListener;

  /// Injected pause between Linux native-window command retries.
  final Future<void> Function(Duration) waitForWindowState;

  _WindowCloseRelay? _relay;

  @override
  Future<void> prepare({required bool startHidden}) async {
    await initialize();
    if (chrome.usesCustomTitleBar) {
      // Configure while the native window is still hidden so its system title
      // bar cannot flash before Flutter paints the first frame.
      await configureCustomTitleBar(enabled: true);
    }
    await readyToShow(() async {
      if (!startHidden) await showWindow();
    });
    // A production window starts hidden, while an integration runner already
    // owns a visible window. Enforce the requested state after readiness so
    // both compositions have the same observable behavior.
    if (startHidden) {
      await hide();
    } else {
      _setVisible(true);
    }
  }

  @override
  Future<void> show() async {
    await showWindow();
    _setVisible(true);
  }

  @override
  Future<void> hide() async {
    await hideWindow();
    // Window managers can acknowledge the method call before applying it, and
    // can drop that first request while the compositor is busy; macOS applies
    // an early hide as lazily as a busy Linux compositor does. Hide is
    // idempotent, so confirm the native state and retry briefly before
    // publishing the app-level state.
    for (var attempt = 0; attempt < 10; attempt += 1) {
      if (!await windowIsVisible()) break;
      await waitForWindowState(const Duration(milliseconds: 50));
      await hideWindow();
    }
    _setVisible(false);
  }

  @override
  Future<bool> isVisible() => windowIsVisible();

  @override
  Future<void> startDragging() => startWindowDrag();

  @override
  Future<void> minimize() => minimizeWindow();

  @override
  Future<void> toggleMaximized() async {
    // The plugin's native query can lag behind a just-completed maximize call.
    // The notifier is updated optimistically here and by native window events,
    // so it remains authoritative even for back-to-back button presses.
    final next = !_maximized.value;
    await (next ? maximizeWindow() : unmaximizeWindow());
    _setMaximized(next);
  }

  @override
  Future<void> interceptClose(void Function() onClose) async {
    await releaseClose();
    final relay = _WindowCloseRelay(onClose, _setMaximized, _setVisible);
    _relay = relay;
    addWindowListener(relay);
    await preventClose(prevent: true);
  }

  @override
  Future<void> releaseClose() async {
    final relay = _relay;
    if (relay == null) return;
    _relay = null;
    removeWindowListener(relay);
    await preventClose(prevent: false);
  }

  void _setMaximized(bool value) {
    if (_maximized.value != value) _maximized.value = value;
  }

  void _setVisible(bool value) {
    if (_visible.value != value) _visible.value = value;
  }
}

final class _WindowCloseRelay with WindowListener {
  new(this.onClose, this.onMaximizedChanged, this.onVisibleChanged);

  final void Function() onClose;
  final ValueChanged<bool> onMaximizedChanged;
  final ValueChanged<bool> onVisibleChanged;

  @override
  void onWindowClose() => onClose();

  @override
  void onWindowMaximize() => onMaximizedChanged(true);

  @override
  void onWindowUnmaximize() => onMaximizedChanged(false);

  /// Reports a hide or show the app did not ask for.
  ///
  /// The plugin has no typed callback for either, but both the Linux
  /// (`linux/window_manager_plugin.cc`, the GTK `show` and `hide` signals) and
  /// the Windows implementation emit them as raw events.
  @override
  void onWindowEvent(String eventName) {
    switch (eventName) {
      case 'show':
        onVisibleChanged(true);
      case 'hide':
        onVisibleChanged(false);
    }
  }
}

/// Production tray adapter backed by `tray_manager`.
final class PluginTrayIcon implements TrayIcon {
  /// Creates the production tray adapter.
  new({
    TargetPlatform? platform,
    this.setIcon = _setTrayIcon,
    this.setToolTip = _setTrayToolTip,
    this.setContextMenu = _setTrayContextMenu,
    this.popUpMenu = _popUpTrayContextMenu,
    this.addTrayListener = _addTrayListener,
    this.removeTrayListener = _removeTrayListener,
    this.destroyTray = _destroyTray,
  }) : platform = platform ?? defaultTargetPlatform;

  /// Platform used to choose the icon format and the available calls.
  final TargetPlatform platform;

  /// Injected icon assignment.
  final Future<void> Function(String path, {required bool isTemplate}) setIcon;

  /// Injected tooltip assignment.
  final Future<void> Function(String) setToolTip;

  /// Injected context-menu assignment.
  final Future<void> Function(Menu) setContextMenu;

  /// Injected context-menu popup.
  final Future<void> Function({required bool bringAppToFront}) popUpMenu;

  /// Injected listener registration.
  final void Function(TrayListener) addTrayListener;

  /// Injected listener removal.
  final void Function(TrayListener) removeTrayListener;

  /// Injected tray destruction.
  final Future<void> Function() destroyTray;

  _TraySelectionRelay? _relay;

  @override
  Future<void> install({
    required TrayMenuModel menu,
    required void Function(String itemKey) onSelected,
    required void Function() onActivated,
  }) async {
    await destroy();
    final relay = _TraySelectionRelay(
      onSelected: onSelected,
      onLeftClick: _leftClick(onActivated),
      onRightClick: _rightClick,
    );
    _relay = relay;
    addTrayListener(relay);
    await setIcon(
      trayIconAssetPath(platform: platform),
      isTemplate: platform == TargetPlatform.macOS,
    );
    await update(menu);
  }

  @override
  Future<void> update(TrayMenuModel menu) async {
    // The Linux plugin answers `setToolTip` with `notImplemented`, so asking
    // for one there would throw instead of degrading.
    if (platform != TargetPlatform.linux) await setToolTip(menu.tooltip);
    await setContextMenu(_nativeMenu(menu));
  }

  @override
  Future<void> destroy() async {
    final relay = _relay;
    if (relay == null) return;
    _relay = null;
    removeTrayListener(relay);
    await destroyTray();
  }

  /// What a left click on the icon means on this platform.
  ///
  /// Windows treats it as "bring the app back". macOS opens the menu from
  /// either button, the way every other menu-bar item does. Linux never
  /// reports icon clicks at all, because the app indicator owns the gesture.
  void Function() _leftClick(void Function() onActivated) => switch (platform) {
    TargetPlatform.windows => onActivated,
    TargetPlatform.macOS => _rightClick,
    _ => _ignoreClick,
  };

  /// Shows the menu the platform will not show on its own.
  ///
  /// Only the Linux plugin attaches the menu to the icon; on Windows and macOS
  /// the plugin merely reports the click, so nothing appears unless the app
  /// asks. Windows also needs the window foregrounded, or `TrackPopupMenu`
  /// leaves a menu that a click elsewhere cannot dismiss.
  void _rightClick() {
    switch (platform) {
      case TargetPlatform.windows:
        unawaited(popUpMenu(bringAppToFront: true));
      case TargetPlatform.macOS:
        unawaited(popUpMenu(bringAppToFront: false));
      case _:
        break;
    }
  }

  static void _ignoreClick() {}
}

/// Production terminator that ends this process.
final class ProcessAppTerminator implements AppTerminator {
  /// Creates the production terminator.
  const new({this.exitProcess = exit});

  /// Injected process exit, which is the only part a test can drive.
  final Never Function(int code) exitProcess;

  @override
  Future<void> terminate() async => exitProcess(0);
}

/// Converts the app's tray presentation into a native menu.
Menu buildNativeTrayMenu(TrayMenuModel menu) => _nativeMenu(menu);

Menu _nativeMenu(TrayMenuModel menu) => Menu(
  items: <MenuItem>[
    for (final entry in menu.entries)
      if (entry.isSeparator)
        MenuItem.separator()
      else
        MenuItem(key: entry.key, label: entry.label, disabled: !entry.enabled),
  ],
);

final class _TraySelectionRelay with TrayListener {
  new({
    required this.onSelected,
    required this.onLeftClick,
    required this.onRightClick,
  });

  final void Function(String itemKey) onSelected;
  final void Function() onLeftClick;
  final void Function() onRightClick;

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) onSelected(key);
  }

  // Windows reports a double click as two of these, so whatever they do has to
  // be idempotent.
  @override
  void onTrayIconMouseDown() => onLeftClick();

  @override
  void onTrayIconRightMouseDown() => onRightClick();
}

/// Production login-item adapter backed by `launch_at_startup`.
final class LaunchAtStartupRegistration implements AutostartRegistration {
  /// Creates the production login-item adapter.
  const new({
    this.configure = _configureStartup,
    this.enableStartup = _enableStartup,
    this.disableStartup = _disableStartup,
    this.startupIsEnabled = _startupIsEnabled,
  });

  /// Login-item name, also the Linux `.desktop` file name.
  ///
  /// The plugin does not quote the `Exec=` line, so this must not contain a
  /// space.
  static const String appName = AppIdentity.configDirectoryName;

  /// Injected `launchAtStartup.setup`.
  final void Function({required String appPath, required List<String> args})
  configure;

  /// Injected registration.
  final Future<void> Function() enableStartup;

  /// Injected removal.
  final Future<void> Function() disableStartup;

  /// Injected registration query.
  final Future<bool> Function() startupIsEnabled;

  @override
  Future<void> apply({required bool enabled, required bool minimized}) async {
    // The arguments are baked in when the launcher is configured, so a change
    // to `minimized` has to re-register rather than only toggle.
    configure(
      appPath: Platform.resolvedExecutable,
      args: minimized ? const <String>[startMinimizedFlag] : const <String>[],
    );
    await (enabled ? enableStartup() : disableStartup());
  }

  @override
  Future<bool> isEnabled() => startupIsEnabled();
}

// The remaining functions are one-line bridges to plugin singletons. They are
// the only part of this file a test cannot drive, which is why every adapter
// takes them as injected parameters.

Future<void> _ensureInitialized() => windowManager.ensureInitialized();

Future<void> _configureCustomTitleBar({required bool enabled}) =>
    windowManager.setTitleBarStyle(
      enabled ? TitleBarStyle.hidden : TitleBarStyle.normal,
      windowButtonVisibility: !enabled,
    );

Future<void> _waitUntilReadyToShow(Future<void> Function() onReady) =>
    windowManager.waitUntilReadyToShow(null, onReady);

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

Future<void> _hideWindow() => windowManager.hide();

Future<bool> _windowIsVisible() => windowManager.isVisible();

Future<void> _startWindowDrag() => windowManager.startDragging();

Future<void> _minimizeWindow() => windowManager.minimize();

Future<void> _maximizeWindow() => windowManager.maximize();

Future<void> _unmaximizeWindow() => windowManager.unmaximize();

Future<void> _setPreventClose({required bool prevent}) =>
    windowManager.setPreventClose(prevent);

Future<void> _waitForWindowState(Duration duration) =>
    Future<void>.delayed(duration);

void _addWindowListener(WindowListener listener) =>
    windowManager.addListener(listener);

void _removeWindowListener(WindowListener listener) =>
    windowManager.removeListener(listener);

Future<void> _setTrayIcon(String path, {required bool isTemplate}) =>
    trayManager.setIcon(path, isTemplate: isTemplate);

Future<void> _setTrayToolTip(String tooltip) => trayManager.setToolTip(tooltip);

Future<void> _setTrayContextMenu(Menu menu) => trayManager.setContextMenu(menu);

Future<void> _popUpTrayContextMenu({required bool bringAppToFront}) {
  if (!bringAppToFront) return trayManager.popUpContextMenu();
  // The plugin marks this Windows-only flag deprecated, but it is the only
  // way to reach the `SetForegroundWindow` that Win32 requires before
  // `TrackPopupMenu`; without it a click elsewhere cannot dismiss the menu.
  // It only foregrounds an existing window, so a tray-resident app stays
  // hidden until the user asks for it.
  // ignore: deprecated_member_use
  return trayManager.popUpContextMenu(bringAppToFront: true);
}

void _addTrayListener(TrayListener listener) =>
    trayManager.addListener(listener);

void _removeTrayListener(TrayListener listener) =>
    trayManager.removeListener(listener);

Future<void> _destroyTray() => trayManager.destroy();

void _configureStartup({required String appPath, required List<String> args}) =>
    launchAtStartup.setup(
      appName: LaunchAtStartupRegistration.appName,
      appPath: appPath,
      args: args,
    );

Future<void> _enableStartup() async {
  await launchAtStartup.enable();
}

Future<void> _disableStartup() async {
  await launchAtStartup.disable();
}

Future<bool> _startupIsEnabled() => launchAtStartup.isEnabled();
