import 'dart:io';

import 'package:agent/agent.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// Deltas per scripted turn.
///
/// One SQLite row is written per streamed delta, so a handful of turns is
/// enough to build a history that no single frame should ever carry.
const int _deltasPerTurn = 40;
const int _turns = 4;

/// Bundled deterministic model whose declared surface supports the v5 Agent.
const String _testModelId = 'openai/gpt-5.6-sol';

void main() {
  test(
    'a real daemon serves a bounded newest window and pages backwards through '
    'history without gaps or overlap',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-history-home-',
      );
      final userHome = await Directory.systemTemp.createTemp(
        'tinest-history-user-',
      );
      const token = 'history-token-0123456789abcdef0123456789';
      DaemonHandle? handle;
      TinestClient? client;
      try {
        handle = await DaemonApplication.start(
          DaemonConfig(
            homeDirectory: home.path,
            userHomeDirectory: userHome.path,
            port: 0,
            bearerToken: token,
            useEnvironmentCredentials: false,
          ),
          provider: _ChattyProvider(),
        );
        client = await TinestClient.connect(
          endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
          credentials: const DaemonCredentials(bearerToken: token),
          clientId: 'history-paging',
          clientKind: 'test',
        );
        final catalog = await client.workspaces.getWorkspaceCatalog();
        final homeWorkspace = catalog.workspaces.singleWhere(
          (workspace) => workspace.kind == WorkspaceKind.home,
        );
        final checkout = catalog.worktrees.singleWhere(
          (worktree) => worktree.workspaceId == homeWorkspace.id,
        );
        final session = await client.sessions.createSession(
          id: 'history-session',
          worktreeId: checkout.id,
          title: 'History session',
          agentDefinitionId: 'tinest',
          model: const ModelSelectionDto(modelId: _testModelId),
        );
        for (var turn = 1; turn <= _turns; turn += 1) {
          await client.sessions.startTurn(
            sessionId: session.id,
            turnId: 'turn-$turn',
            prompt: 'Say something $turn',
          );
          await _waitForIdle(client, session.id);
        }

        final full = await client.sessions.subscribeTimeline(session.id);
        expect(
          full.map((event) => event.sequence),
          orderedEquals(List<int>.generate(full.length, (i) => i + 1)),
          reason: 'sequences are 1-based and contiguous per session',
        );
        expect(
          full.length,
          greaterThan(_deltasPerTurn * _turns),
          reason: 'the scripted turns must produce a multi-page history',
        );

        // An unbounded subscribe is unchanged: existing callers keep the
        // whole history without asking for anything new.
        const pageSize = 30;
        final newest = await client.sessions.subscribeTimeline(
          session.id,
          tailLimit: pageSize,
        );
        expect(newest.last.sequence, full.last.sequence);
        expect(newest.length, lessThan(full.length));
        expect(
          newest.length,
          greaterThanOrEqualTo(pageSize),
          reason: 'the window grows to a turn boundary, it never shrinks',
        );
        expect(
          newest.length,
          lessThanOrEqualTo(pageSize * 2),
          reason:
              'alignment must not undo the limit: one streamed turn is one '
              'row per delta and would otherwise rebuild the whole frame',
        );
        expect(
          newest.map((event) => event.sequence),
          orderedEquals(
            List<int>.generate(newest.length, (i) => newest.first.sequence + i),
          ),
        );
        final newestTurn = full.last.turnId;
        expect(
          full
              .where((event) => event.turnId == newestTurn)
              .every((event) => event.sequence >= newest.first.sequence),
          isTrue,
          reason: 'the newest turn is never split across a page boundary',
        );

        // A turn far larger than the window is split rather than delivered
        // whole, because a turn is one row per streamed delta and alignment
        // would otherwise rebuild the frame the limit exists to bound.
        final tiny = await client.sessions.subscribeTimeline(
          session.id,
          tailLimit: 5,
        );
        expect(tiny.length, lessThanOrEqualTo(10));
        expect(tiny.last.sequence, full.last.sequence);

        // Walk backwards to the beginning; the pages must reassemble into
        // exactly the full history.
        final walked = <TimelineEventDto>[...newest];
        var cursor = newest.first.sequence;
        while (cursor > 1) {
          final page = await client.sessions.readTimelineHistory(
            session.id,
            beforeSequence: cursor,
            limit: pageSize,
          );
          expect(page, isNotEmpty, reason: 'history before $cursor exists');
          expect(page.last.sequence, cursor - 1, reason: 'no gap at $cursor');
          walked.insertAll(0, page);
          cursor = page.first.sequence;
        }
        expect(
          walked.map((event) => event.sequence),
          orderedEquals(full.map((event) => event.sequence)),
        );

        // Paging past the beginning is empty rather than an error, which is
        // what lets the client stop without a separate "has more" flag.
        expect(
          await client.sessions.readTimelineHistory(
            session.id,
            beforeSequence: 1,
            limit: pageSize,
          ),
          isEmpty,
        );

        // A block outlives the page boundary that splits it. Without this the
        // oldest row a reader holds is renamed by its own page load, which to
        // a list anchored by identity is that row being deleted.
        final blocks = <String, String>{};
        for (final event in full) {
          if (event.type != 'assistant.delta') continue;
          final blockId = event.data['blockId'];
          expect(
            blockId,
            isA<String>(),
            reason: 'every streamed delta names the block it belongs to',
          );
          blocks[blockId! as String] ??= event.turnId!;
        }
        expect(
          blocks,
          hasLength(_turns),
          reason: 'one uninterrupted answer per turn is one block',
        );
        expect(blocks.values.toSet(), hasLength(_turns));
        // The tiny window above is smaller than one answer, so it opens
        // mid-block. It must name the block it is continuing rather than
        // inventing one from the oldest delta it happens to hold.
        final opening = tiny.firstWhere(
          (event) => event.type == 'assistant.delta',
        );
        final preceding = full.lastWhere(
          (event) =>
              event.type == 'assistant.delta' &&
              event.sequence < opening.sequence,
        );
        expect(
          preceding.turnId,
          opening.turnId,
          reason: 'the tiny window has to split one answer to prove anything',
        );
        expect(
          opening.data['blockId'],
          preceding.data['blockId'],
          reason: 'a page boundary does not rename the block it splits',
        );
      } finally {
        await client?.close();
        await handle?.stop();
        await home.delete(recursive: true);
        await userHome.delete(recursive: true);
      }
    },
    tags: const <String>[
      'feature_test__conversation_history_pagination__verticalSlice',
    ],
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _waitForIdle(TinestApi client, String sessionId) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    final sessions = await client.sessions.listSessions();
    final session = sessions.where((item) => item.id == sessionId).firstOrNull;
    if (session != null && session.status == SessionStatus.idle) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Timed out waiting for $sessionId to go idle.');
}

/// Streams enough deltas that one turn alone spans several pages.
final class _ChattyProvider implements ModelGateway {
  @override
  String get id => 'history-test';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    final buffer = StringBuffer();
    for (var index = 0; index < _deltasPerTurn; index += 1) {
      cancellation.throwIfCancelled();
      final delta = 'chunk $index ';
      buffer.write(delta);
      yield ModelTextDelta(delta);
    }
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: buffer.toString()),
    );
  }
}
