import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Scrollable monospace block used for tool arguments and command output.
///
/// Content is capped before layout so a multi-megabyte command output cannot
/// stall a frame.
class ChatCodeBlock extends StatelessWidget {
  /// Creates a code block.
  const new({
    required this.text,
    this.language,
    this.maxLines = 24,
    this.maxCharacters = 20000,
    this.showCopy = true,
    super.key,
  });

  /// Raw text to render.
  final String text;

  /// Language a highlighter can recognise, or null for plain text.
  final String? language;

  /// Lines shown before the block is truncated.
  final int maxLines;

  /// Characters kept before the text is truncated.
  final int maxCharacters;

  /// Whether the copy affordance is offered.
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    final capped = text.length > maxCharacters
        ? text.substring(0, maxCharacters)
        : text;
    final lines = capped.split('\n');
    final visible = lines.length > maxLines
        ? lines.take(maxLines).join('\n')
        : capped;
    final hidden = lines.length > maxLines ? lines.length - maxLines : 0;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The block hosts no selection of its own: the enclosing card or
        // response owns one, so a drag runs from the surrounding text through
        // the code instead of stopping at its edge.
        TRCodeBlock(
          code: visible,
          language: language,
          trailing: showCopy
              ? TRIconButton(
                  appearance: TRAppearance.ghost,
                  uiSize: TinestUiDensity.compactControlSize(context),
                  label: l10n.commonCopy,
                  // The untruncated text, so a capped block still copies whole.
                  onPressed: () => Clipboard.setData(ClipboardData(text: text)),
                  icon: const Icon(TinestIcons.copy),
                )
              : null,
        ),
        // Outside the surface: a count of what was dropped is not code, and
        // inside it the line would land in every selection of the block.
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: TRSpacing.extraSmall),
            child: TRText(
              l10n.chatMoreLines(hidden),
              variant: TRTextVariant.bodySm,
              color: TRTextColor.muted,
            ),
          ),
      ],
    );
  }
}
