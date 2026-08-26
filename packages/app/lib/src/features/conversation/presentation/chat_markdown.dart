import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/features/conversation/presentation/chat_code_block.dart';
import 'package:flutter/material.dart' as legacy_material;
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Schemes a chat link is allowed to open.
const Set<String> chatLinkSchemes = <String>{'http', 'https', 'mailto'};

/// Renders every fenced block in assistant prose on the shared code surface.
///
/// The Markdown package draws its own `pre`, which leaves a fenced block
/// looking unlike the identical payload a tool call shows and with no way to
/// copy it. Routing it here gives both, and keeps the horizontal scrolling a
/// long line needs.
Map<String, MarkdownElementBuilder> chatMarkdownBuilders() =>
    <String, MarkdownElementBuilder>{'pre': _ChatFencedCodeBuilder()};

class _ChatFencedCodeBuilder extends MarkdownElementBuilder {
  static final RegExp _language = RegExp(r'\blanguage-(\S+)');

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final fence = element.children?.whereType<md.Element>().firstOrNull;
    final classes = fence?.attributes['class'];
    // A fence closes with a newline the block does not have to render.
    return ChatCodeBlock(
      text: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
      language: classes == null
          ? null
          : _language.firstMatch(classes)?.group(1),
    );
  }
}

/// Markdown styling for assistant prose.
///
/// The Markdown package styles its blocks with raw `TextStyle` and
/// `BoxDecoration`, so this is the adapter that maps Tinyrack tokens onto that
/// API. Every value here still comes from a token.
MarkdownStyleSheet chatMarkdownStyleSheet(BuildContext context) {
  final colors = context.tinyrackTheme;
  final brightness = Theme.of(context).brightness;
  // flutter_markdown_plus has not migrated to Flutter 3.47's material_ui
  // package yet. Map only public Tinyrack theme values into the legacy type
  // its API requires; this adapter owns no independent visual decisions.
  final legacyTheme = legacy_material.ThemeData(
    brightness: brightness,
    primaryColor: colors.primaryForeground,
    cardColor: colors.surfaceMuted,
    dividerColor: colors.border,
    colorScheme:
        legacy_material.ColorScheme.fromSeed(
          seedColor: colors.primaryForeground,
          brightness: brightness,
        ).copyWith(
          primary: colors.primaryForeground,
          surfaceContainerHighest: colors.surfaceMuted,
        ),
    textTheme: legacy_material.TextTheme(
      bodyMedium: TRTypography.resolve(context, TRTextVariant.body),
      bodyLarge: TRTypography.resolve(context, TRTextVariant.body),
      headlineSmall: TRTypography.resolve(context, TRTextVariant.headingLg),
      titleLarge: TRTypography.resolve(context, TRTextVariant.headingMd),
      titleMedium: TRTypography.resolve(context, TRTextVariant.headingSm),
    ),
  );
  final base = MarkdownStyleSheet.fromTheme(legacyTheme);
  return base.copyWith(
    p: TRTypography.resolve(
      context,
      TRTextVariant.body,
    ).copyWith(color: colors.text),
    // RenderParagraph paints the shared SelectionArea highlight before span
    // backgrounds. An opaque inline-code fill would therefore cover the
    // selection and make one continuous drag look fragmented.
    code: TRTypography.resolve(
      context,
      TRTextVariant.code,
    ).copyWith(color: colors.text),
    codeblockDecoration: BoxDecoration(
      color: colors.surfaceMuted,
      borderRadius: const BorderRadius.all(TRRadii.medium),
    ),
    codeblockPadding: const EdgeInsets.all(TRSpacing.small),
    blockquoteDecoration: BoxDecoration(
      color: colors.surfaceMuted,
      borderRadius: const BorderRadius.all(TRRadii.medium),
    ),
    a: TRTypography.resolve(context, TRTextVariant.body).copyWith(
      color: colors.primaryForeground,
      decoration: TextDecoration.underline,
    ),
    blockSpacing: TRSpacing.small,
  );
}

/// One Markdown stylesheet shared by every chat block beneath it.
///
/// [chatMarkdownStyleSheet] runs `ColorScheme.fromSeed`, which generates a full
/// tonal palette. Every visible assistant message rebuilds on every streamed
/// delta, so computing it per message per frame is the most expensive thing in
/// a running transcript. Hosting one instance above the list makes it a single
/// computation per theme rather than per row, without moving a single design
/// value out of a token.
class ChatMarkdownTheme extends StatelessWidget {
  /// Creates a shared Markdown stylesheet scope.
  const ChatMarkdownTheme({required this.child, super.key});

  /// Subtree whose Markdown bodies share one stylesheet.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      // The sheet is derived from the legacy bridge's context, which is where
      // the Markdown package reads its theme from, so the scope has to sit
      // inside the bridge rather than around it.
      // ignore: deprecated_member_use
      MaterialUiCompatibilityBridge(
        child: Builder(
          builder: (legacyContext) => _ChatMarkdownStyleScope(
            styleSheet: chatMarkdownStyleSheet(legacyContext),
            child: child,
          ),
        ),
      );
}

class _ChatMarkdownStyleScope extends InheritedWidget {
  const _ChatMarkdownStyleScope({
    required this.styleSheet,
    required super.child,
  });

  final MarkdownStyleSheet styleSheet;

  static MarkdownStyleSheet? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ChatMarkdownStyleScope>()
      ?.styleSheet;

  @override
  bool updateShouldNotify(_ChatMarkdownStyleScope oldWidget) =>
      // Value equality: the sheet is rebuilt whenever this scope rebuilds, and
      // a theme that did not change produces an equal one.
      styleSheet != oldWidget.styleSheet;
}

/// Markdown renderer isolated behind the documented legacy-package bridge.
///
/// `flutter_markdown_plus` still imports Flutter's legacy Material library.
/// Keeping the compatibility boundary here prevents that dependency's theme
/// and localization types from leaking into the rest of Tinest.
class ChatMarkdownBody extends StatelessWidget {
  /// Creates a Markdown body for one chat block.
  const ChatMarkdownBody({required this.data, this.onTapLink, super.key});

  /// Markdown source rendered by the legacy dependency.
  final String data;

  /// Link activation callback.
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    // Shared when a [ChatMarkdownTheme] is above this block, which is the case
    // for every message in the transcript. Standalone use falls back to its own
    // sheet so this stays usable on its own.
    final shared = _ChatMarkdownStyleScope.maybeOf(context);
    if (shared != null) {
      return MarkdownBody(
        data: data,
        builders: chatMarkdownBuilders(),
        styleSheet: shared,
        onTapLink: onTapLink,
      );
    }
    // material_ui documents this bridge for dependencies that have not yet
    // migrated. The scope is deliberately limited to flutter_markdown_plus.
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: Builder(
        builder: (legacyContext) => MarkdownBody(
          data: data,
          builders: chatMarkdownBuilders(),
          styleSheet: chatMarkdownStyleSheet(legacyContext),
          onTapLink: onTapLink,
        ),
      ),
    );
  }
}

/// Opens a Markdown link, ignoring schemes that are not browser-safe.
Future<void> openChatLink(ExternalUrlOpener opener, String? href) async {
  if (href == null || href.isEmpty) return;
  final uri = Uri.tryParse(href);
  if (uri == null || !chatLinkSchemes.contains(uri.scheme)) return;
  await opener.open(uri);
}

/// One selectable Markdown document whose copied blocks retain separators.
///
/// Flutter's default multi-selectable delegate concatenates each selected
/// widget without delimiters. Markdown renders headings, paragraphs, bullets,
/// quotes, and code blocks as separate widgets, so the default result loses
/// every block boundary and the space after a bullet.
class ChatMarkdownSelectionArea extends StatefulWidget {
  /// Creates a selectable Markdown document.
  const ChatMarkdownSelectionArea({required this.child, super.key});

  /// Markdown content and any response-owned actions below it.
  final Widget child;

  @override
  State<ChatMarkdownSelectionArea> createState() =>
      _ChatMarkdownSelectionAreaState();
}

class _ChatMarkdownSelectionAreaState extends State<ChatMarkdownSelectionArea> {
  final _delegate = _ChatMarkdownSelectionDelegate();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: SelectionContainer(delegate: _delegate, child: widget.child),
  );
}

class _ChatMarkdownSelectionDelegate extends StaticSelectionContainerDelegate {
  @override
  SelectedContent? getSelectedContent() {
    final selected = <({Rect bounds, String text})>[];
    for (final selectable in selectables) {
      final content = selectable.getSelectedContent();
      if (content == null || content.plainText.isEmpty) continue;
      final transform = getTransformFrom(selectable);
      final boxes = selectable.boundingBoxes;
      if (boxes.isEmpty) continue;
      var bounds = MatrixUtils.transformRect(transform, boxes.first);
      for (final box in boxes.skip(1)) {
        bounds = bounds.expandToInclude(
          MatrixUtils.transformRect(transform, box),
        );
      }
      selected.add((bounds: bounds, text: content.plainText));
    }
    if (selected.isEmpty) return null;

    final buffer = StringBuffer();
    Rect? previous;
    for (final item in selected) {
      if (previous case final bounds?) {
        final sharesLine =
            bounds.top < item.bounds.bottom && item.bounds.top < bounds.bottom;
        buffer.write(sharesLine ? ' ' : '\n');
      }
      buffer.write(item.text);
      previous = item.bounds;
    }
    return SelectedContent(plainText: buffer.toString());
  }
}
