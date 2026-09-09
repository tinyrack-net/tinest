import 'dart:async';

import 'package:app/src/features/desktop/domain/tray_menu_model.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:flutter/foundation.dart';

/// Records window control without opening a native window.
final class FakeDesktopWindow implements DesktopWindow {
  /// Creates a fake window that starts visible unless told otherwise.
  new({bool visible = true, this.chrome = DesktopWindowChrome.native})
    : _visible = ValueNotifier<bool>(visible);

  @override
  final DesktopWindowChrome chrome;

  final ValueNotifier<bool> _maximized = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get maximized => _maximized;

  final ValueNotifier<bool> _visible;

  @override
  ValueListenable<bool> get visible => _visible;

  /// Reports a hide or show the app did not ask for, the way the OS can.
  ///
  /// Only a real change is reported, the way the production adapter does.
  void emitNativeVisibility({required bool visible}) {
    if (_visible.value != visible) _visible.value = visible;
  }

  /// Whether the close gesture is being intercepted.
  bool preventingClose = false;

  /// Value recorded by the last [prepare] call, or null when never prepared.
  bool? preparedHidden;

  /// Counts of each destructive call, so ordering can be asserted.
  int shows = 0;
  int hides = 0;
  int drags = 0;
  int minimizes = 0;
  int maximizeToggles = 0;

  /// Order in which teardown steps ran, used by the quit test.
  final List<String> calls = <String>[];

  void Function()? _onClose;

  /// Drives the native close gesture from a test.
  void requestClose() => _onClose?.call();

  @override
  Future<void> prepare({required bool startHidden}) async {
    preparedHidden = startHidden;
    _visible.value = !startHidden;
  }

  @override
  Future<void> show() async {
    shows += 1;
    _visible.value = true;
    calls.add('show');
  }

  @override
  Future<void> hide() async {
    hides += 1;
    _visible.value = false;
    calls.add('hide');
  }

  @override
  Future<bool> isVisible() async => _visible.value;

  @override
  Future<void> startDragging() async {
    drags += 1;
    calls.add('drag');
  }

  @override
  Future<void> minimize() async {
    minimizes += 1;
    calls.add('minimize');
  }

  @override
  Future<void> toggleMaximized() async {
    maximizeToggles += 1;
    _maximized.value = !_maximized.value;
    calls.add(_maximized.value ? 'maximize' : 'unmaximize');
  }

  @override
  Future<void> interceptClose(void Function() onClose) async {
    _onClose = onClose;
    preventingClose = true;
  }

  @override
  Future<void> releaseClose() async {
    _onClose = null;
    preventingClose = false;
    calls.add('releaseClose');
  }
}

/// Records the process-ending call instead of killing the test runner.
final class FakeAppTerminator implements AppTerminator {
  /// Creates a terminator that only counts requests.
  new({this.calls});

  /// Number of times the app asked to end the process.
  int terminations = 0;

  /// Shared ordering log, assigned by tests that assert teardown order.
  List<String>? calls;

  @override
  Future<void> terminate() async {
    terminations += 1;
    calls?.add('terminate');
  }
}

/// Records tray installation and menu updates without a native tray.
final class FakeTrayIcon implements TrayIcon {
  /// Creates a fake tray, optionally holding [installGate] open mid-install.
  ///
  /// A held gate reproduces a real tray, where installing the icon takes long
  /// enough for another frame to ask for a menu update.
  new({this.installGate});

  /// Completed by a test to let a pending [install] finish.
  final Completer<void>? installGate;

  /// Every menu handed to the tray, in order, starting with the installed one.
  final List<TrayMenuModel> menus = <TrayMenuModel>[];

  /// Which tray calls ran, in order, as `install` and `update`.
  final List<String> operations = <String>[];

  /// Number of times the icon was installed.
  int installs = 0;

  /// Number of times the icon was destroyed.
  int destroys = 0;

  /// Shared ordering log, assigned by tests that assert teardown order.
  List<String>? calls;

  void Function(String itemKey)? _onSelected;
  void Function()? _onActivated;

  /// The menu the tray is currently showing.
  TrayMenuModel get menu => menus.last;

  /// Drives a tray selection from a test.
  void select(String itemKey) => _onSelected?.call(itemKey);

  /// Drives a click on the tray icon itself from a test.
  void activate() => _onActivated?.call();

  @override
  Future<void> install({
    required TrayMenuModel menu,
    required void Function(String itemKey) onSelected,
    required void Function() onActivated,
  }) async {
    installs += 1;
    operations.add('install');
    _onSelected = onSelected;
    _onActivated = onActivated;
    menus.add(menu);
    await installGate?.future;
  }

  @override
  Future<void> update(TrayMenuModel menu) async {
    operations.add('update');
    menus.add(menu);
  }

  @override
  Future<void> destroy() async {
    destroys += 1;
    _onSelected = null;
    _onActivated = null;
    calls?.add('destroyTray');
  }
}

/// Records login-item registration without touching the real home directory.
final class FakeAutostartRegistration implements AutostartRegistration {
  /// Creates a fake registration that starts unregistered.
  new({this.enabled = false});

  /// Whether the operating system would launch the app at login.
  bool enabled;

  /// Whether the recorded launch arguments ask for a hidden start.
  bool minimized = false;

  /// Every [apply] call, in order.
  final List<({bool enabled, bool minimized})> applications =
      <({bool enabled, bool minimized})>[];

  @override
  Future<void> apply({required bool enabled, required bool minimized}) async {
    applications.add((enabled: enabled, minimized: minimized));
    this.enabled = enabled;
    this.minimized = minimized;
  }

  @override
  Future<bool> isEnabled() async => enabled;
}
