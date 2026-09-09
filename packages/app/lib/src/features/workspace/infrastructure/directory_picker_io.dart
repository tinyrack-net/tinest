import 'package:app/src/features/workspace/application/directory_picker_port.dart';
import 'package:file_selector/file_selector.dart';

export 'package:app/src/features/workspace/application/directory_picker_port.dart';

/// Production desktop folder chooser.
final class NativeDirectoryPicker implements DirectoryPickerPort {
  /// Creates the native folder chooser.
  const new();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) =>
      getDirectoryPath(initialDirectory: initialDirectory);
}
