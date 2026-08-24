import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
export 'package:protocol/local_host.dart';

/// Reads a daemon bearer token from the v5 owner-restricted secret document.
Future<String?> readLocalDaemonBearerToken(String configDirectory) async {
  final file = File(p.join(configDirectory, 'v5', 'secrets.json'));
  if (!file.existsSync()) return null;
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 2) {
    throw FormatException(
      'incompatible_credentials: explicitly remove ${file.path} to reset '
      'development credentials.',
    );
  }
  final daemon = decoded['daemon'];
  if (daemon == null) return null;
  if (daemon is! Map<String, dynamic> || daemon['bearerToken'] is! String) {
    throw const FormatException('Invalid daemon credential data.');
  }
  return daemon['bearerToken'] as String;
}
