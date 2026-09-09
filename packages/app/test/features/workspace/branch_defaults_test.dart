import 'package:app/src/features/workspace/domain/branch_defaults.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  const local = GitBranchDto(name: 'main', current: true, checkedOut: true);
  const feature = GitBranchDto(
    name: 'feature',
    current: false,
    checkedOut: false,
  );
  const originMain = GitBranchDto(
    name: 'origin/main',
    current: false,
    checkedOut: false,
    isRemote: true,
  );
  const originMaster = GitBranchDto(
    name: 'origin/master',
    current: false,
    checkedOut: false,
    isRemote: true,
  );
  const originTrunk = GitBranchDto(
    name: 'origin/trunk',
    current: false,
    checkedOut: false,
    isRemote: true,
    isDefault: true,
  );

  test('the base branch prefers the latest remote default', () {
    expect(
      defaultBaseBranch(const <GitBranchDto>[local, originMaster, originMain]),
      'origin/main',
    );
    expect(
      defaultBaseBranch(const <GitBranchDto>[local, originMaster]),
      'origin/master',
    );
    expect(
      defaultBaseBranch(const <GitBranchDto>[local, originTrunk]),
      'origin/trunk',
    );
    expect(defaultBaseBranch(const <GitBranchDto>[feature, local]), 'main');
    expect(defaultBaseBranch(const <GitBranchDto>[feature]), 'feature');
    expect(defaultBaseBranch(const <GitBranchDto>[]), isNull);
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

  test('a local branch named like a remote default does not win', () {
    expect(
      defaultBaseBranch(const <GitBranchDto>[
        GitBranchDto(name: 'origin/main', current: false, checkedOut: false),
        local,
      ]),
      'main',
    );
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);
}
