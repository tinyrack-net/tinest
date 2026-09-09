import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens external authorization pages outside the Flutter application.
abstract interface class ExternalUrlOpener {
  /// Opens [uri] in the platform's external application.
  Future<bool> open(Uri uri);
}

/// Production external URL adapter backed by Flutter's maintained launcher.
final class PlatformExternalUrlOpener implements ExternalUrlOpener {
  /// Creates the production URL opener.
  const new();

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// External authorization URL adapter supplied by the app composition root.
final externalUrlOpenerProvider = Provider<ExternalUrlOpener>(
  (ref) => throw StateError('ExternalUrlOpener must be overridden.'),
);
