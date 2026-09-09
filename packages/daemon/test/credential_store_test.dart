import 'dart:convert';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/credential_store.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'stores provider and daemon credentials atomically in one protected file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tinest-credential-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final expiresAt = DateTime.utc(2026, 8, 2, 12);
      final store = CredentialStore(directory.path);

      await store.setCredential(
        'deepseek',
        const ApiKeyCredential('api-secret'),
      );
      await store.setCredential(
        'openai',
        OAuthCredential(
          accessToken: 'access-secret',
          refreshToken: 'refresh-secret',
          expiresAt: expiresAt,
          accountId: 'account-id',
        ),
      );
      await store.setDaemonToken('daemon-secret');
      await store.setRelayIdentityPrivateKey(List<int>.generate(32, (i) => i));

      final reloaded = CredentialStore(directory.path);
      await reloaded.load();
      expect(
        reloaded.credential('deepseek'),
        isA<ApiKeyCredential>().having(
          (credential) => credential.key,
          'key',
          'api-secret',
        ),
      );
      expect(
        reloaded.credential('openai'),
        isA<OAuthCredential>()
            .having(
              (credential) => credential.accessToken,
              'access token',
              'access-secret',
            )
            .having(
              (credential) => credential.refreshToken,
              'refresh token',
              'refresh-secret',
            )
            .having(
              (credential) => credential.expiresAt,
              'expiration',
              expiresAt,
            ),
      );
      expect(reloaded.bearerToken, 'daemon-secret');
      expect(
        reloaded.relayIdentityPrivateKey,
        List<int>.generate(32, (i) => i),
      );

      final credentialsJson = await File('${directory.path}/secrets.json')
          .readAsString();
      expect(jsonDecode(credentialsJson), <String, dynamic>{
        'schemaVersion': 2,
        'daemon': <String, dynamic>{
          'bearerToken': 'daemon-secret',
          'relayIdentityPrivateKey': base64UrlEncode(
            List<int>.generate(32, (i) => i),
          ),
        },
        'providerCredentials': <String, dynamic>{
          'deepseek': <String, dynamic>{'type': 'apiKey', 'key': 'api-secret'},
          'openai': <String, dynamic>{
            'type': 'oauth',
            'accessToken': 'access-secret',
            'refreshToken': 'refresh-secret',
            'expiresAt': expiresAt.toIso8601String(),
            'accountId': 'account-id',
          },
        },
      });
      expect(credentialsJson, contains('daemon-secret'));
      expect(credentialsJson, contains('api-secret'));
      expect(credentialsJson, contains('access-secret'));
      expect(File('${directory.path}/auth.json').existsSync(), isFalse);

      if (!Platform.isWindows) {
        expect(
          File('${directory.path}/secrets.json').statSync().mode & 0x1ff,
          0x180,
        );
      }
    },
  );

  test('rejects obsolete dual-token credential documents explicitly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tinest-obsolete-credential-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/secrets.json');
    await file.writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 0,
        'daemon': <String, dynamic>{
          'bearerToken': 'bearer',
          'adminToken': 'obsolete',
        },
        'providerCredentials': <String, dynamic>{},
      }),
    );

    await expectLater(
      CredentialStore(directory.path).load(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('incompatible_credentials'),
        ),
      ),
    );
  });

  test('MCP secrets live beside provider credentials', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tinest-credential-mcp-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = CredentialStore(directory.path);

    await store.setMcpSecret('github.token', 'mcp-secret');
    await store.setCredential('openai', const ApiKeyCredential('api-secret'));

    final reloaded = CredentialStore(directory.path);
    await reloaded.load();
    expect(reloaded.mcpSecrets, <String, String>{'github.token': 'mcp-secret'});
    expect(reloaded.credential('openai'), isA<ApiKeyCredential>());

    await reloaded.setMcpSecret('github.token', 'rotated');
    await reloaded.removeMcpSecret('absent');
    expect(reloaded.mcpSecrets['github.token'], 'rotated');

    await reloaded.removeMcpSecret('github.token');
    final rereloaded = CredentialStore(directory.path);
    await rereloaded.load();
    expect(rereloaded.mcpSecrets, isEmpty);
  });

  test('a file carrying a malformed MCP secret is rejected', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tinest-credential-mcp-invalid-',
    );
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/secrets.json').writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 2,
        'providerCredentials': <String, dynamic>{},
        'mcpSecrets': <String, dynamic>{'github.token': 42},
      }),
    );

    await expectLater(
      CredentialStore(directory.path).load(),
      throwsA(isA<FormatException>()),
    );
  });

  test('a rewrite leaves the credentials file in place throughout', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tinest-credential-rewrite-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = CredentialStore(directory.path);
    final file = File(p.join(directory.path, 'secrets.json'));

    // A daemon writes twice before it finishes starting — a token, then a
    // relay key — and every provider change writes again. None of those may
    // reach the disk by way of a moment where the file is missing: a process
    // that stops there has destroyed the credentials rather than updated
    // them, and on Windows the write throws outright if anything still holds
    // the file it is about to unlink.
    await store.setDaemonToken('first-token');
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await store.setCredential(
        'openai',
        ApiKeyCredential('api-secret-$attempt'),
      );
      expect(file.existsSync(), isTrue);
    }

    final reloaded = CredentialStore(directory.path);
    await reloaded.load();
    expect(reloaded.bearerToken, 'first-token');
    expect(
      reloaded.credential('openai'),
      isA<ApiKeyCredential>().having(
        (credential) => credential.key,
        'key',
        'api-secret-19',
      ),
    );
    expect(
      File('${file.path}.tmp').existsSync(),
      isFalse,
      reason: 'the staging file is renamed away, not left behind',
    );
  });

  test('removing one credential preserves the remaining credentials', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tinest-credential-remove-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = CredentialStore(directory.path);
    await store.setCredential('first', const ApiKeyCredential('first-secret'));
    await store.setCredential(
      'second',
      const ApiKeyCredential('second-secret'),
    );

    await store.removeCredential('first');

    final reloaded = CredentialStore(directory.path);
    await reloaded.load();
    expect(reloaded.credential('first'), isNull);
    expect(reloaded.credential('second'), isA<ApiKeyCredential>());
  });
}
