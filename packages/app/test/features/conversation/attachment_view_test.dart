import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

void main() {
  testWidgets(
    'image attachments open a lightbox and files use the export port',
    tags: const <String>['feature_test__conversation_attachments__widget'],
    (tester) async {
      const image = ChatAttachment(
        id: 'image-1',
        fileName: 'fixture.png',
        mimeType: 'image/png',
        byteSize: 68,
      );
      const file = ChatAttachment(
        id: 'file-1',
        fileName: 'result.txt',
        mimeType: 'text/plain',
        byteSize: 5,
      );
      ChatAttachment? exported;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+'
        'A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: testLightTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: ChatTimelineView(
              sessionKey: 'attachment-view-test',
              busy: false,
              items: <ChatItem>[
                ChatUserMessage(
                  key: 'user',
                  turnId: 'turn',
                  createdAt: DateTime.utc(2026),
                  text: '',
                  attachments: <ChatAttachment>[image],
                ),
                ChatAttachmentMessage(
                  key: 'assistant-file',
                  turnId: 'turn',
                  createdAt: DateTime.utc(2026),
                  attachment: file,
                ),
              ],
              loadAttachment: (attachment) async => attachment.isImage
                  ? Uint8List.fromList(png)
                  : Uint8List.fromList(utf8.encode('hello')),
              exportAttachment: (attachment) async {
                exported = attachment;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TRChatMessageRow>(find.byType(TRChatMessageRow))
            .alignment,
        TRChatMessageAlignment.center,
      );
      await tester.tap(find.byKey(const ValueKey('chat-attachment-image-1')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      Navigator.of(tester.element(find.byType(InteractiveViewer))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-attachment-file-1')));
      await tester.pump();
      expect(exported?.id, 'file-1');
    },
  );
}
