import 'package:app/src/features/workspace/domain/branch_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompts become git-safe branch slugs', () {
    expect(deriveWorktreeBranchName('Fix the parser'), 'fix-the-parser');
    expect(deriveWorktreeBranchName('Fix   the\nparser bug'), 'fix-the');
    expect(deriveWorktreeBranchName('Add v2.1 support'), 'add-v2.1-support');
    expect(deriveWorktreeBranchName('  ---Trim me---  '), 'trim-me');
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

  test('unusable prompts fall back to the default slug', () {
    expect(deriveWorktreeBranchName(''), defaultWorktreeBranchName);
    expect(deriveWorktreeBranchName('   '), defaultWorktreeBranchName);
    expect(deriveWorktreeBranchName('파서를 고쳐줘'), defaultWorktreeBranchName);
    expect(deriveWorktreeBranchName('...'), defaultWorktreeBranchName);
    expect(deriveWorktreeBranchName('..'), defaultWorktreeBranchName);
    expect(deriveWorktreeBranchName('release.lock'), 'release.lock-branch');
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

  test('long prompts truncate on a separator without trailing punctuation', () {
    final long = deriveWorktreeBranchName(
      'Rewrite the entire parser module and its extensive regression tests',
    );
    expect(long.length, lessThanOrEqualTo(maxWorktreeBranchNameLength));
    expect(long.endsWith('-'), isFalse);
    expect(long, 'rewrite-the-entire-parser-module-and-its');

    final unbroken = deriveWorktreeBranchName('a' * 80);
    expect(unbroken.length, maxWorktreeBranchNameLength);
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

  test('existing worktree names are avoided', () {
    expect(
      deriveWorktreeBranchName(
        'Fix the parser',
        existingBranchNames: <String>['fix-the-parser'],
      ),
      'fix-the-parser-2',
    );
    expect(
      deriveWorktreeBranchName(
        'Fix the parser',
        existingBranchNames: <String>['fix-the-parser', 'Fix The Parser 2'],
      ),
      'fix-the-parser-3',
    );
    expect(
      deriveWorktreeBranchName(
        '파서를 고쳐줘',
        existingBranchNames: <String>[defaultWorktreeBranchName],
      ),
      '$defaultWorktreeBranchName-2',
    );
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);
}
