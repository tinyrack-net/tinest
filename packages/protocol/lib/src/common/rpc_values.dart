/// Parameters for a procedure that accepts no values.
final class EmptyParamsDto {
  /// Creates empty parameters.
  const new();

  /// Decodes an empty object.
  factory fromJson(Map<String, dynamic> json) {
    if (json.isNotEmpty) throw const FormatException('Expected empty params.');
    return const EmptyParamsDto();
  }

  /// Encodes this value.
  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

/// Result for a procedure that returns no values.
final class EmptyResultDto {
  /// Creates an empty result.
  const new();

  /// Decodes an empty object.
  factory fromJson(Map<String, dynamic> json) {
    if (json.isNotEmpty) throw const FormatException('Expected empty result.');
    return const EmptyResultDto();
  }

  /// Encodes this value.
  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

/// Stable JSON-RPC failure data transported independently of its message.
final class RpcFailureDto {
  /// Creates stable failure data.
  const new({
    required this.code,
    this.retryable = false,
    this.details = const <String, dynamic>{},
  });

  /// Decodes failure data.
  factory fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final retryable = json['retryable'];
    final details = json['details'];
    if (code is! String || retryable is! bool || details is! Map) {
      throw const FormatException('Invalid RPC failure.');
    }
    return RpcFailureDto(
      code: code,
      retryable: retryable,
      details: Map<String, dynamic>.from(details),
    );
  }

  /// Stable machine-readable failure code.
  final String code;

  /// Whether retrying can succeed without changing the request.
  final bool retryable;

  /// Structured failure details safe to expose to a client.
  final Map<String, dynamic> details;

  /// Encodes this value.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'retryable': retryable,
    'details': details,
  };
}
