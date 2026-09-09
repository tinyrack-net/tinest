/// Resource controls shared by Tinest quality commands.
final class QualityCommandOptions {
  /// Creates resolved common command options.
  const new({required this.jobs, required this.reportPath});

  /// Effective global process budget.
  final int jobs;

  /// Optional machine-readable report destination.
  final String? reportPath;
}

/// Resolves the process budget using CLI, environment, then host precedence.
int resolveQualityJobs({
  required int? cliJobs,
  required Map<String, String> environment,
  required int detectedJobs,
}) {
  if (detectedJobs <= 0) {
    throw ArgumentError.value(detectedJobs, 'detectedJobs', 'must be positive');
  }
  final environmentValue = environment['TINEST_JOBS'];
  final environmentJobs = environmentValue == null
      ? null
      : _positiveInt(environmentValue, 'TINEST_JOBS');
  return cliJobs ?? environmentJobs ?? detectedJobs;
}

int _positiveInt(String value, String source) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$source must be a positive integer');
  }
  return parsed;
}
