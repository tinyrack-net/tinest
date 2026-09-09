import 'package:app/l10n/app_localization_config.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/desktop/presentation/desktop_shell_scope.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/workspace/application/directory_picker_port.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Tinest application composition.
class TinestApp extends StatelessWidget {
  /// Creates the application.
  new({
    required this.services,
    this.attachmentInput,
    this.directoryPicker,
    this.externalUrlOpener = const PlatformExternalUrlOpener(),
    this.desktopWindow,
    this.trayIcon,
    this.terminator,
    this.autostart,
    this.initialLocation,
    super.key,
  });

  /// Platform services used by feature controllers.
  final AppServices services;

  /// Platform file picker, clipboard, and desktop drop adapter.
  final AttachmentInputPort? attachmentInput;

  /// Native folder chooser used for hosts that share this filesystem.
  final DirectoryPickerPort? directoryPicker;

  /// Opens interactive provider authorization pages.
  final ExternalUrlOpener externalUrlOpener;

  /// Desktop window control, or null on platforms without a window to manage.
  final DesktopWindow? desktopWindow;

  /// Tray icon owner, or null on platforms without a tray.
  final TrayIcon? trayIcon;

  /// Process terminator, or null where quitting is not the app's to perform.
  final AppTerminator? terminator;

  /// Login-item registration, or null where the app cannot register one.
  final AutostartRegistration? autostart;

  /// Optional startup route supplied by a native protocol activation.
  final String? initialLocation;

  late final GoRouter _router = GoRouter(
    routes: $appRoutes,
    initialLocation: initialLocation,
  );

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appServicesProvider.overrideWithValue(services),
      attachmentInputProvider.overrideWithValue(attachmentInput),
      directoryPickerProvider.overrideWithValue(directoryPicker),
      externalUrlOpenerProvider.overrideWithValue(externalUrlOpener),
      desktopWindowProvider.overrideWithValue(desktopWindow),
      trayIconProvider.overrideWithValue(trayIcon),
      appTerminatorProvider.overrideWithValue(terminator),
      autostartProvider.overrideWithValue(autostart),
    ],
    child: _TinestAppView(
      router: _router,
      resident: desktopWindow != null || trayIcon != null,
    ),
  );
}

/// Builds the app shell below [ProviderScope] so it can watch settings.
class _TinestAppView extends ConsumerWidget {
  const new({required this.router, required this.resident});

  final GoRouter router;

  /// Whether this build owns a tray and can survive a closed window.
  final bool resident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selecting the two values this build reads, rather than the settings
    // object, keeps unrelated writes such as the tab layout from rebuilding
    // the whole app below the router.
    final themeMode = ref.watch(
      hostRegistryControllerProvider.select(
        (value) => value.value?.settings.themeMode,
      ),
    );
    final localeTag = ref.watch(
      hostRegistryControllerProvider.select(
        (value) => value.value?.settings.localeTag,
      ),
    );
    return MaterialApp.router(
      title: AppIdentity.displayName,
      debugShowCheckedModeBanner: false,
      theme: tinestTheme(Brightness.light),
      darkTheme: tinestTheme(Brightness.dark),
      // Settings that have not loaded yet follow the platform, which is also
      // the stored default, so the first frame never flips brightness.
      themeMode: tinestThemeMode(themeMode ?? AppThemeMode.system),
      // A null locale lets Flutter resolve the system locale against
      // [AppLocalizations.supportedLocales], which falls back to English.
      locale: localeTag == null ? null : Locale(localeTag),
      localizationsDelegates: tinestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // The shell sits below Localizations and the router so tray labels
      // follow the selected language and a tray row can navigate.
      builder: (context, child) => TinestUiDensity(
        child: TRContextMenuPresenterScope(
          // The one place a concrete presenter is named. A widget test that
          // omits this scope gets the deterministic Flutter presentation
          // instead of a menu the operating system would draw outside the
          // tree.
          presenter: const TRNativeContextMenuPresenter(),
          child: TRTooltipProvider(
            // Outside the desktop shell rather than inside it: that shell
            // only builds where the platform has a window to dress, so a
            // report placed within it would never reach mobile or the web.
            child: TinestToastScope(
              child: !resident
                  ? child ?? const SizedBox.shrink()
                  : DesktopShellScope(
                      router: router,
                      child: child ?? const SizedBox.shrink(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the shared Material theme for one brightness.
ThemeData tinestTheme(Brightness brightness) => brightness == Brightness.light
    ? TinyrackTheme.light()
    : TinyrackTheme.dark();

/// Translates the stored appearance choice into the widget-layer mode.
ThemeMode tinestThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
