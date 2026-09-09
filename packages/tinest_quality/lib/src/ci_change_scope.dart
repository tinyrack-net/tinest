/// The conservative verification scope for a pull request.
enum CiChangeScope {
  /// Only documentation files changed.
  docsOnly('docs-only'),

  /// Only the relay package changed.
  relayOnly('relay-only'),

  /// Only the Flutter application changed.
  appOnly('app-only'),

  /// The complete workspace must be verified.
  full('full');

  new(this.outputValue);

  /// Value emitted for consumption by GitHub Actions.
  final String outputValue;

  /// Resolves the smallest safe verification scope for [changedFiles].
  static CiChangeScope forPullRequest(Iterable<String> changedFiles) {
    final files = changedFiles
        .map((file) => file.trim())
        .where((file) => file.isNotEmpty)
        .toList(growable: false);
    if (files.isEmpty) return full;
    if (files.every(_isDocumentation)) return docsOnly;
    if (files.every((file) => file.startsWith('packages/relay/'))) {
      return relayOnly;
    }
    if (files.every(
      (file) =>
          file.startsWith('packages/app/') ||
          file.startsWith('packages/desktop_app/'),
    )) {
      return appOnly;
    }
    return full;
  }

  static bool _isDocumentation(String file) =>
      file.startsWith('docs/') || file.endsWith('.md');
}
