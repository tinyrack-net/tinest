import 'dart:async';
import 'dart:typed_data';

import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_message_views.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

/// A 1x1 transparent PNG, so the decoded preview path is exercised for real.
final Uint8List _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

void main() {
  const attachment = ChatAttachment(
    id: 'attachment-1',
    fileName: 'diagram.png',
    mimeType: 'image/png',
    byteSize: 67,
  );

  Widget host(ChatAttachmentLoader loader) => MaterialApp(
    theme: testLightTheme,
    locale: testLocale,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    home: Scaffold(
      body: ChatAttachmentTile(attachment: attachment, loadAttachment: loader),
    ),
  );

  testWidgets('an image preview shows a skeleton and downloads exactly once', (
    tester,
  ) async {
    var calls = 0;
    final bytes = Completer<Uint8List>();
    Future<Uint8List> loader(ChatAttachment _) {
      calls += 1;
      return bytes.future;
    }

    await tester.pumpWidget(host(loader));
    expect(find.byType(TRSkeleton), findsOneWidget);
    expect(find.byType(TRSpinner), findsNothing);

    // Rebuilding the same attachment must not refire the download.
    await tester.pumpWidget(host(loader));
    expect(calls, 1);

    bytes.complete(_transparentPng);
    await tester.pumpAndSettle();
    expect(find.byType(TRSkeleton), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(calls, 1);
  }, tags: const <String>['feature_test__workspace_async_loading__widget']);
}
