import 'package:agent/agent.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

const _tags = <String>['feature_test__turn_execution__unit'];

void main() {
  late MemoryFileSystem fileSystem;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
  });

  Future<void> write(String path, String contents) async {
    final file = fileSystem.file(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  ProjectDocLoader loader({int maxBytes = 32 * 1024}) =>
      ProjectDocLoader(fileSystem: fileSystem, maxBytes: maxBytes);

  test('returns null when nothing is documented', tags: _tags, () async {
    await fileSystem.directory('/w').create(recursive: true);
    expect(await loader().load(workspaceRoot: '/w'), isNull);
  });

  test('reads the document at the workspace root', tags: _tags, () async {
    await write('/w/AGENTS.md', 'root rules');
    final loaded = await loader().load(workspaceRoot: '/w');
    expect(loaded, isNotNull);
    expect(loaded!.text, contains('root rules'));
    expect(loaded.paths, <String>['/w/AGENTS.md']);
  });

  test('concatenates root to leaf in order', tags: _tags, () async {
    await write('/w/AGENTS.md', 'root rules');
    await write('/w/pkg/AGENTS.md', 'package rules');
    final loaded = await loader().load(
      workspaceRoot: '/w',
      workingDirectory: '/w/pkg',
    );
    expect(loaded!.paths, <String>['/w/AGENTS.md', '/w/pkg/AGENTS.md']);
    expect(
      loaded.text.indexOf('root rules'),
      lessThan(loaded.text.indexOf('package rules')),
    );
    expect(loaded.text, contains('--- project-doc ---'));
  });

  test('prefers the local override in a directory', tags: _tags, () async {
    await write('/w/AGENTS.md', 'checked in');
    await write('/w/AGENTS.override.md', 'local only');
    final loaded = await loader().load(workspaceRoot: '/w');
    expect(loaded!.text, contains('local only'));
    expect(loaded.text, isNot(contains('checked in')));
  });

  test('never walks above the workspace root', tags: _tags, () async {
    await write('/AGENTS.md', 'outside');
    await write('/w/AGENTS.md', 'inside');
    final loaded = await loader().load(workspaceRoot: '/w');
    expect(loaded!.text, contains('inside'));
    expect(loaded.text, isNot(contains('outside')));
  });

  test('ignores a working directory outside the root', tags: _tags, () async {
    await write('/w/AGENTS.md', 'inside');
    await write('/elsewhere/AGENTS.md', 'outside');
    final loaded = await loader().load(
      workspaceRoot: '/w',
      workingDirectory: '/elsewhere',
    );
    expect(loaded!.paths, <String>['/w/AGENTS.md']);
  });

  test('skips a document with nothing but whitespace', tags: _tags, () async {
    await write('/w/AGENTS.md', '   \n\n');
    expect(await loader().load(workspaceRoot: '/w'), isNull);
  });

  test('truncates once the budget runs out', tags: _tags, () async {
    await write('/w/AGENTS.md', 'a' * 10);
    await write('/w/pkg/AGENTS.md', 'b' * 10);
    final loaded = await loader(maxBytes: 15)
        .load(workspaceRoot: '/w', workingDirectory: '/w/pkg');
    expect(loaded!.text, contains('a' * 10));
    expect(loaded.text, contains('b' * 5));
    expect(loaded.text, isNot(contains('b' * 6)));
  });

  test('stops reading once the budget is spent', tags: _tags, () async {
    await write('/w/AGENTS.md', 'a' * 10);
    await write('/w/pkg/AGENTS.md', 'b' * 10);
    final loaded = await loader(maxBytes: 10)
        .load(workspaceRoot: '/w', workingDirectory: '/w/pkg');
    expect(loaded!.paths, <String>['/w/AGENTS.md']);
  });

  test('marks the document as user data when rendered', tags: _tags, () async {
    await write('/w/AGENTS.md', 'root rules');
    final loaded = await loader().load(workspaceRoot: '/w');
    final rendered = loaded!.render();
    expect(rendered, contains('<project_doc'));
    expect(rendered, contains('root rules'));
    expect(rendered, contains('user-provided data'));
  });
}
