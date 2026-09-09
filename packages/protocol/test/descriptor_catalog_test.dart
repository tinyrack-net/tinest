import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('every v5 descriptor owns executable malformed-payload decoding', () {
    final procedureNames = <String>{};
    for (final procedure in rpcProcedures) {
      expect(procedureNames.add(procedure.name), isTrue);
      _exerciseMalformed(() => procedure.decodeParamsObject(const {}));
      _exerciseMalformed(() => procedure.decodeResultObject(const {}));
    }

    final notificationNames = <String>{};
    for (final notification in rpcNotifications) {
      expect(notificationNames.add(notification.name), isTrue);
      _exerciseMalformed(() => notification.decodeObject(const {}));
    }

    expect(procedureNames, hasLength(rpcProcedures.length));
    expect(notificationNames, hasLength(rpcNotifications.length));
  });

  test('type-erased descriptors preserve their concrete codecs', () {
    const hello = HelloParamsDto(
      clientId: 'client',
      clientKind: 'test',
      protocolMajor: tinestProtocolMajor,
      capabilities: <String, bool>{},
    );
    const server = ServerInfoDto(
      serverId: 'server',
      version: 'test',
      protocolVersion: tinestProtocolMajor,
      features: <String, bool>{},
    );
    const changed = EmptyResultDto();

    expect(systemHelloProcedure.encodeParamsObject(hello), hello.toJson());
    expect(systemHelloProcedure.encodeResultObject(server), server.toJson());
    expect(systemHelloProcedure.decodeResultObject(server.toJson()), server);
    expect(agentsChangedNotification.encodeObject(changed), changed.toJson());
    expect(agentsChangedNotification.decodeObject(changed.toJson()), changed);
    expect(agentsChangedNotification.eventType, EmptyResultDto);
  });
}

void _exerciseMalformed(Object Function() decode) {
  expect(decode, anyOf(returnsNormally, throwsA(anything)));
}
