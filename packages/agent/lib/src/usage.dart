/// Token counters one model response reported, normalized across providers.
///
/// The Responses API and the Chat Completions API spell every counter
/// differently and nest the cache and reasoning numbers one level down. This
/// is the single shape the agent, the timeline, and the context budget read,
/// so nothing downstream has to know which API answered.
final class ModelUsage {
  /// Creates a [ModelUsage].
  const new({
    this.inputTokens = 0,
    this.cachedInputTokens = 0,
    this.outputTokens = 0,
    this.reasoningTokens = 0,
    this.totalTokens = 0,
  });

  /// Decodes a persisted or transported usage snapshot.
  factory fromJson(Map<String, dynamic> json) => ModelUsage(
    inputTokens: _int(json['inputTokens']),
    cachedInputTokens: _int(json['cachedInputTokens']),
    outputTokens: _int(json['outputTokens']),
    reasoningTokens: _int(json['reasoningTokens']),
    totalTokens: _int(json['totalTokens']),
  );

  /// Prompt tokens the provider billed, including any cached prefix.
  final int inputTokens;

  /// Portion of [inputTokens] served from the provider's prompt cache.
  final int cachedInputTokens;

  /// Tokens the model produced, including any reasoning it did not show.
  final int outputTokens;

  /// Portion of [outputTokens] spent on hidden reasoning.
  final int reasoningTokens;

  /// Total the provider reported; zero when it reported none.
  final int totalTokens;

  /// Tokens the current context window holds after this response.
  ///
  /// Providers that report a total are trusted; the rest are summed, which is
  /// the same number for every API observed so far.
  int get contextTokens =>
      totalTokens > 0 ? totalTokens : inputTokens + outputTokens;

  /// Whether the provider reported no counters at all.
  ///
  /// Chat Completions sends usage in its own trailing chunk, so the stream
  /// decoder needs this to tell "no usage yet" from "usage of zero".
  bool get isEmpty =>
      inputTokens == 0 &&
      cachedInputTokens == 0 &&
      outputTokens == 0 &&
      reasoningTokens == 0 &&
      totalTokens == 0;

  /// Encodes the snapshot for the timeline and the wire.
  Map<String, int> toJson() => <String, int>{
    'inputTokens': inputTokens,
    'cachedInputTokens': cachedInputTokens,
    'outputTokens': outputTokens,
    'reasoningTokens': reasoningTokens,
    'totalTokens': totalTokens,
  };

  static int _int(Object? value) => value is int ? value : 0;

  @override
  String toString() =>
      'ModelUsage(input: $inputTokens, cached: $cachedInputTokens, '
      'output: $outputTokens, reasoning: $reasoningTokens, '
      'total: $totalTokens)';
}
