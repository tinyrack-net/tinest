import 'package:agent/agent.dart';
import 'package:daemon/src/features/sessions/infrastructure/model_usage_cost.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('prices uncached, cached, and output tokens per million', () {
    final cost = modelUsageCostUsd(
      const ModelUsage(
        inputTokens: 1000000,
        cachedInputTokens: 250000,
        outputTokens: 500000,
      ),
      const ModelPricingDto(input: 4, cacheRead: 1, output: 12),
    );

    expect(cost, 9.25);
  }, tags: 'feature_test__tool_context_budget__unit');

  test('falls back to input pricing for cached input', () {
    final cost = modelUsageCostUsd(
      const ModelUsage(inputTokens: 1000, cachedInputTokens: 1000),
      const ModelPricingDto(input: 2, output: 8),
    );

    expect(cost, 0.002);
  }, tags: 'feature_test__tool_context_budget__unit');

  test('returns null when a used token class has unknown pricing', () {
    expect(
      modelUsageCostUsd(
        const ModelUsage(inputTokens: 10, outputTokens: 5),
        const ModelPricingDto(input: 2),
      ),
      isNull,
    );
    expect(modelUsageCostUsd(const ModelUsage(inputTokens: 10), null), isNull);
  }, tags: 'feature_test__tool_context_budget__unit');
}
