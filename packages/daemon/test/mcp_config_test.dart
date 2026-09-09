@Tags(<String>['feature_test__mcp_server_management__unit'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/mcp/infrastructure/mcp_config.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late FileMcpConfigStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tinest-mcp-config-');
    store = FileMcpConfigStore(directory.path);
  });

  tearDown(() => directory.delete(recursive: true));

  String userPath() => store.sourcePath(McpConfigScope.user);

  Map<String, dynamic> v5Document(Map<String, dynamic> document) =>
      <String, dynamic>{
        'schemaVersion': document['version'] == 1 ? 5 : document['version'],
        'mcp': <String, dynamic>{
          'servers': document['servers'] ?? <String, dynamic>{},
        },
      };

  Future<void> writeUser(Map<String, dynamic> document) =>
      File(userPath()).writeAsString(jsonEncode(v5Document(document)));

  Future<void> writeProject(String root, String contents) async {
    final file = File(store.sourcePath(McpConfigScope.project, rootPath: root));
    await file.parent.create(recursive: true);
    final document = jsonDecode(contents) as Map<String, dynamic>;
    await file.writeAsString(jsonEncode(v5Document(document)));
  }

  test('the user and project scopes name their own files', () {
    expect(p.basename(userPath()), 'config.json');
    expect(
      store.sourcePath(McpConfigScope.project, rootPath: '/repo'),
      p.join('/repo', '.tinest', 'config.json'),
    );
    expect(
      () => store.sourcePath(McpConfigScope.project),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a missing file loads as an empty document', () async {
    final user = await store.load(McpConfigScope.user);
    expect(user.servers, isEmpty);
    expect(user.scope, McpConfigScope.user);
    expect(user.sourcePath, userPath());

    final project = await store.load(
      McpConfigScope.project,
      rootPath: directory.path,
    );
    expect(project.servers, isEmpty);
    expect(project.scope, McpConfigScope.project);
  });

  test('v5 rejects a preserved v4 MCP document without importing it', () {
    expect(
      () => parseMcpConfig(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 4,
          'mcp': <String, dynamic>{'servers': <String, dynamic>{}},
        }),
        scope: McpConfigScope.user,
        sourcePath: 'v4-config.json',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      parseMcpConfig(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 5,
          'mcp': <String, dynamic>{'servers': <String, dynamic>{}},
        }),
        scope: McpConfigScope.user,
        sourcePath: 'v5-config.json',
      ).servers,
      isEmpty,
    );
  });

  test('servers round-trip through a written user document', () async {
    await store.save(
      McpConfigDocument(
        scope: McpConfigScope.user,
        sourcePath: userPath(),
        servers: <McpServerConfigDto>[
          const McpServerConfigDto(
            id: 'github',
            transport: McpTransportKind.stdio,
            command: 'npx',
            args: <String>['-y', 'server-github'],
            env: <String, String>{'TOKEN': r'${secret:github.token}'},
            cwd: '/repo',
          ),
          const McpServerConfigDto(
            id: 'linear',
            enabled: false,
            transport: McpTransportKind.http,
            url: 'https://mcp.linear.test/mcp',
            headers: <String, String>{'authorization': r'${env:LINEAR}'},
          ),
        ],
      ),
    );

    final reloaded = await store.load(McpConfigScope.user);
    expect(reloaded.servers.map((server) => server.id), <String>[
      'github',
      'linear',
    ]);
    final github = reloaded.servers.first;
    expect(github.transport, McpTransportKind.stdio);
    expect(github.command, 'npx');
    expect(github.args, <String>['-y', 'server-github']);
    expect(github.env, <String, String>{'TOKEN': r'${secret:github.token}'});
    expect(github.cwd, '/repo');
    expect(github.enabled, isTrue);
    final linear = reloaded.servers.last;
    expect(linear.enabled, isFalse);
    expect(linear.url, 'https://mcp.linear.test/mcp');
    expect(linear.headers, <String, String>{'authorization': r'${env:LINEAR}'});
  });

  test('the written file is protected and indented', () async {
    await store.save(
      McpConfigDocument(
        scope: McpConfigScope.user,
        sourcePath: userPath(),
        servers: const <McpServerConfigDto>[
          McpServerConfigDto(
            id: 'github',
            transport: McpTransportKind.stdio,
            command: 'npx',
          ),
        ],
      ),
    );

    final contents = await File(userPath()).readAsString();
    expect(contents, contains('\n  "schemaVersion": 5'));
    if (!Platform.isWindows) {
      // Read the mode through dart:io rather than stat, whose flags differ
      // between GNU and BSD userlands.
      final mode = File(userPath()).statSync().mode & 0x1FF;
      expect(mode.toRadixString(8), '600');
      expect(File('${userPath()}.tmp').existsSync(), isFalse);
    }
  });

  test('an incompatible version is rejected instead of migrated', () async {
    await writeUser(<String, dynamic>{
      'version': 99,
      'servers': <String, dynamic>{},
    });

    await expectLater(
      store.load(McpConfigScope.user),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('invalid_mcp_config'), contains(userPath())),
        ),
      ),
    );
  });

  test('a document that is not an object is rejected', () async {
    await File(userPath()).writeAsString('[]');

    await expectLater(
      store.load(McpConfigScope.user),
      throwsA(isA<FormatException>()),
    );
  });

  test('a project document loads from the worktree root', () async {
    await writeProject(directory.path, '''
{
  "version": 1,
  "servers": {
    "repo": {
      "transport": "stdio",
      "command": "./tools/mcp"
    }
  }
}
''');

    final document = await store.load(
      McpConfigScope.project,
      rootPath: directory.path,
    );

    expect(document.servers.single.id, 'repo');
    expect(document.servers.single.command, './tools/mcp');
    expect(document.scope, McpConfigScope.project);
  });

  test('the project scope is read-only', () async {
    await expectLater(
      store.save(
        const McpConfigDocument(
          scope: McpConfigScope.project,
          sourcePath: '/repo/.mcp.json',
          servers: <McpServerConfigDto>[],
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('mcp_project_scope_readonly'),
        ),
      ),
    );
  });

  group('validation', () {
    Future<void> expectRejected(
      Map<String, dynamic> server, {
      required String because,
      String id = 'server',
    }) async {
      await writeUser(<String, dynamic>{
        'version': 1,
        'servers': <String, dynamic>{id: server},
      });
      await expectLater(
        store.load(McpConfigScope.user),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message for $because',
            allOf(contains('invalid_mcp_config'), contains(because)),
          ),
        ),
      );
    }

    test('a server id must survive tool-name namespacing', () async {
      await expectRejected(
        <String, dynamic>{'transport': 'stdio', 'command': 'x'},
        id: 'has__underscores',
        because: 'server id',
      );
      await expectRejected(
        <String, dynamic>{'transport': 'stdio', 'command': 'x'},
        id: 'Uppercase',
        because: 'server id',
      );
      await expectRejected(
        <String, dynamic>{'transport': 'stdio', 'command': 'x'},
        id: '-leading',
        because: 'server id',
      );
      await expectRejected(
        <String, dynamic>{'transport': 'stdio', 'command': 'x'},
        id: 'a' * 41,
        because: 'server id',
      );
    });

    test('an unknown transport is rejected', () async {
      await expectRejected(<String, dynamic>{
        'transport': 'carrier-pigeon',
      }, because: 'transport');
      await expectRejected(<String, dynamic>{}, because: 'transport');
    });

    test('a stdio server needs a command and an absolute cwd', () async {
      await expectRejected(<String, dynamic>{
        'transport': 'stdio',
      }, because: 'command');
      await expectRejected(<String, dynamic>{
        'transport': 'stdio',
        'command': '',
      }, because: 'command');
      await expectRejected(<String, dynamic>{
        'transport': 'stdio',
        'command': 'x',
        'cwd': 'relative/path',
      }, because: 'cwd');
      await expectRejected(<String, dynamic>{
        'transport': 'stdio',
        'command': 'x',
        'args': <dynamic>[1],
      }, because: 'args');
    });

    test('a remote HTTP server must use TLS', () async {
      await expectRejected(<String, dynamic>{
        'transport': 'http',
        'url': 'http://example.test/mcp',
      }, because: 'url');
      await expectRejected(<String, dynamic>{
        'transport': 'http',
      }, because: 'url');
      await expectRejected(<String, dynamic>{
        'transport': 'http',
        'url': 'not a url',
      }, because: 'url');
    });

    test('plain HTTP to the loopback host is allowed', () async {
      await writeUser(<String, dynamic>{
        'version': 1,
        'servers': <String, dynamic>{
          'local': <String, dynamic>{
            'transport': 'http',
            'url': 'http://127.0.0.1:9000/mcp',
          },
          'named': <String, dynamic>{
            'transport': 'http',
            'url': 'http://localhost:9000/mcp',
          },
        },
      });

      final document = await store.load(McpConfigScope.user);

      expect(document.servers, hasLength(2));
    });

    test('an unknown MCP server key is rejected rather than ignored', () async {
      await expectRejected(<String, dynamic>{
        'transport': 'stdio',
        'command': 'x',
        'transprot': 'typo',
      }, because: 'unknown key');
    });

    test('a project document may not carry a literal secret', () async {
      await writeProject(directory.path, '''
{
  "version": 1,
  "servers": {
    "repo": {
      "transport": "http",
      "url": "https://mcp.test/mcp",
      "headers": {"authorization": "Bearer sk-literal"}
    }
  }
}
''');

      await expectLater(
        store.load(McpConfigScope.project, rootPath: directory.path),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('literal secret'),
          ),
        ),
      );
    });

    test(
      'a project document may reference a secret beside plain keys',
      () async {
        await writeProject(directory.path, r'''
{
  "version": 1,
  "servers": {
    "remote": {
      "transport": "http",
      "url": "https://mcp.test/mcp",
      "headers": {
        "authorization": "Bearer ${secret:repo.token}",
        "x-trace": "enabled"
      }
    },
    "local": {
      "transport": "stdio",
      "command": "./tools/mcp",
      "env": {"API_TOKEN": "${env:REPO_TOKEN}", "LOG_LEVEL": "debug"}
    }
  }
}
''');

        final document = await store.load(
          McpConfigScope.project,
          rootPath: directory.path,
        );

        expect(document.servers, hasLength(2));
        expect(document.servers.first.headers['x-trace'], 'enabled');
        expect(document.servers.last.env['LOG_LEVEL'], 'debug');
      },
    );

    test('the user scope may carry a literal secret', () async {
      await writeUser(<String, dynamic>{
        'version': 1,
        'servers': <String, dynamic>{
          'remote': <String, dynamic>{
            'transport': 'http',
            'url': 'https://mcp.test/mcp',
            'headers': <String, dynamic>{'authorization': 'Bearer sk-literal'},
          },
        },
      });

      final document = await store.load(McpConfigScope.user);

      expect(
        document.servers.single.headers['authorization'],
        'Bearer sk-literal',
      );
    });
  });

  group('secret interpolation', () {
    final secrets = <String, String>{'github.token': 'stored-secret'};
    final environment = <String, String>{'LINEAR': 'env-secret'};

    String resolve(String value) =>
        resolveMcpSecrets(value, environment: environment, secrets: secrets);

    test('environment and stored references expand', () {
      expect(resolve(r'${env:LINEAR}'), 'env-secret');
      expect(resolve(r'${secret:github.token}'), 'stored-secret');
      expect(resolve(r'Bearer ${env:LINEAR}!'), 'Bearer env-secret!');
      expect(
        resolve(r'${env:LINEAR}/${secret:github.token}'),
        'env-secret/stored-secret',
      );
    });

    test('literals and escaped dollars pass through', () {
      expect(resolve('plain'), 'plain');
      expect(resolve(r'$$'), r'$');
      expect(resolve(r'$$ {env:LINEAR}'), r'$ {env:LINEAR}');
      expect(resolve(r'costs $5'), r'costs $5');
      expect(resolve(''), '');
    });

    test('an unset variable fails loudly with its name', () {
      expect(
        () => resolve(r'${env:MISSING}'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('mcp_missing_env'), contains('MISSING')),
          ),
        ),
      );
      expect(
        () => resolve(r'${secret:absent}'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('mcp_missing_secret'), contains('absent')),
          ),
        ),
      );
    });

    test('an unterminated or unknown reference is rejected', () {
      expect(() => resolve(r'${env:OPEN'), throwsA(isA<FormatException>()));
      expect(() => resolve(r'${nope:X}'), throwsA(isA<FormatException>()));
    });
  });
}
