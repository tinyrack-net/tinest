import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';

/// Records file search requests and replays scripted matches.
final class FakeFileIndexGateway implements WorkspaceFileIndexGateway {
  /// Creates a fake index; [matches] is keyed by worktree root.
  new({Map<String, List<FileMatchDto>>? matches})
    : matches = matches ?? <String, List<FileMatchDto>>{};

  /// Scripted matches per worktree root.
  final Map<String, List<FileMatchDto>> matches;

  /// Every request this gateway received, in order.
  final List<FileSearchRequest> requests = <FileSearchRequest>[];

  /// Roots passed to [invalidate], in order.
  final List<String> invalidated = <String>[];

  /// Reported on the next search when set.
  bool truncated = false;

  @override
  Future<FileSearchResultDto> search(FileSearchRequest request) async {
    requests.add(request);
    final found = matches[request.root] ?? const <FileMatchDto>[];
    return FileSearchResultDto(
      matches: found.take(request.limit).toList(growable: false),
      truncated: truncated,
    );
  }

  @override
  void invalidate(String root) => invalidated.add(root);
}
