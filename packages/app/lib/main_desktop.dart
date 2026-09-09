import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/boot/presentation/bootstrap_gate.dart';
import 'package:app/src/features/conversation/infrastructure/attachment_io.dart';
import 'package:app/src/features/desktop/application/desktop_startup.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/workspace/infrastructure/directory_picker_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// Everything the desktop entrypoint resolves before it can build [TinestApp].
class DesktopBoot {
  /// Bundles one desktop startup result.
  const new({
    required this.services,
    required this.window,
    required this.tray,
    required this.terminator,
    required this.autostart,
  });

  /// Platform services used by feature controllers.
  final AppServices services;

  /// Native window the app drives.
  final DesktopWindow window;

  /// Tray icon the resident app installs.
  final TrayIcon tray;

  /// Process terminator the quit path ends with.
  final AppTerminator terminator;

  /// Login-item registration port.
  final AutostartRegistration autostart;
}

/// Starts the desktop widget tree with an injectable bootstrap.
Future<void> runDesktopApp({
  AppServices? services,
  Future<AppServices> Function()? bootstrapServices,
  List<String> arguments = const <String>[],
  DesktopWindow? window,
  TrayIcon? tray,
  AppTerminator? terminator,
  AutostartRegistration? autostart,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  Cryptography.instance = FlutterCryptography.defaultInstance;
  runApp(
    BootstrapGate<DesktopBoot>(
      bootstrap: () async {
        final desktopWindow = window ?? PluginDesktopWindow();
        final resolved =
            services ??
            await (bootstrapServices ??
                () => throw StateError(
                  'Desktop production requires an injected service bootstrap.',
                ))();
        // Visibility is decided before the window is prepared so a login
        // launch never flashes a window on its way to the tray. Preparing it
        // is also what tells the shell which label the tray row starts with.
        await desktopWindow.prepare(
          startHidden: shouldStartHidden(
            arguments: arguments,
            settings: await resolved.settings.loadSettings(),
          ),
        );
        return DesktopBoot(
          services: resolved,
          window: desktopWindow,
          tray: tray ?? PluginTrayIcon(),
          terminator: terminator ?? const ProcessAppTerminator(),
          autostart: autostart ?? const LaunchAtStartupRegistration(),
        );
      },
      builder: (context, boot) => TinestApp(
        services: boot.services,
        initialLocation: desktopPairingInitialLocation(arguments),
        attachmentInput: const NativeAttachmentInput(),
        directoryPicker: const NativeDirectoryPicker(),
        desktopWindow: boot.window,
        trayIcon: boot.tray,
        terminator: boot.terminator,
        autostart: boot.autostart,
      ),
    ),
  );
}
