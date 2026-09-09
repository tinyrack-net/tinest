import 'package:app/src/features/hosts/domain/remote_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daemon paths walk up to their parent and stop at the root', () {
    expect(parentDirectoryPath('/srv/repos/project'), '/srv/repos');
    expect(parentDirectoryPath('/srv/repos/project/'), '/srv/repos');
    expect(parentDirectoryPath('/srv'), '/');
    expect(parentDirectoryPath('/'), isNull);
    expect(parentDirectoryPath(''), isNull);
    expect(parentDirectoryPath('   '), isNull);
    expect(parentDirectoryPath('relative'), isNull);
    expect(parentDirectoryPath(r'C:\repos\project'), r'C:\repos');
  }, tags: const <String>['feature_test__workspace_registration__unit']);
}
