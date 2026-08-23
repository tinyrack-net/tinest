@Tags(<String>['feature_test__provider_catalog__unit'])
library;

import 'package:agent/agent.dart';
import 'package:daemon/src/shared/ports/agent_protocol_mapping.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('agent risks map to protocol risks by their canonical names', () {
    for (final risk in AgentToolRisk.values) {
      expect(protocolRisk(risk).name, risk.name);
    }
  });

  test('every typed protocol model control maps to the agent domain', () {
    const protocol = <String, ModelControlValueDto>{
      'choice': ModelControlValueDto.stringValue(value: 'high'),
      'toggle': ModelControlValueDto.boolValue(value: true),
      'integer': ModelControlValueDto.intValue(value: 7),
    };
    final agent = agentModelControls(protocol);
    expect(
      (agent['choice']! as AgentModelControlStringValue).value,
      'high',
    );
    expect((agent['toggle']! as AgentModelControlBoolValue).value, isTrue);
    expect((agent['integer']! as AgentModelControlIntValue).value, 7);
  });

  test('optional pricing and limits preserve absence and every field', () {
    expect(protocolPricing(null), isNull);
    expect(protocolLimits(null), isNull);

    final pricing = protocolPricing(
      const AgentModelPricing(
        input: 1,
        output: 2,
        cacheRead: 3,
        cacheWrite: 4,
      ),
    )!;
    expect(
      <double?>[
        pricing.input,
        pricing.output,
        pricing.cacheRead,
        pricing.cacheWrite,
      ],
      <double?>[1, 2, 3, 4],
    );

    final limits = protocolLimits(
      const AgentModelLimits(context: 100, input: 80, output: 20),
    )!;
    expect(
      <int?>[limits.context, limits.input, limits.output],
      <int?>[100, 80, 20],
    );
  });
}
