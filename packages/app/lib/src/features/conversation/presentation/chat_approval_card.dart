import 'dart:async';
import 'dart:convert';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/presentation/chat_code_block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Renders an actionable tool approval request.
class ApprovalCard extends ConsumerStatefulWidget {
  /// Creates an [ApprovalCard].
  const new({this.hostId, this.approval, this.interaction, super.key})
    : assert(
        approval != null || interaction != null,
        'An approval or timeline interaction is required.',
      );

  /// Stable host profile containing the approval's agent.
  final String? hostId;

  /// The pending approval rendered by this card.
  final ApprovalRequestDto? approval;

  /// Timeline interaction, including a persisted decision when resolved.
  final ChatApprovalInteraction? interaction;

  @override
  ConsumerState<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<ApprovalCard> {
  bool _submitting = false;
  Object? _error;

  ApprovalRequestDto get approval =>
      widget.interaction?.approval ?? widget.approval!;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TRSpacing.extraSmall),
      child: TRCard(
        padding: TRCardPadding.none,
        variant: TRCardVariant.elevated,
        child: Padding(
          padding: const EdgeInsets.all(TRSpacing.medium),
          // One host for the whole card, so the request can be dragged out in
          // full rather than one preview block at a time.
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TRText(
                  l10n.chatApprovalRequired(approval.toolName),
                  variant: TRTextVariant.headingSm,
                ),
                const SizedBox(height: TRSpacing.small),
                _preview(context),
                const SizedBox(height: TRSpacing.small),
                if (_error case final error?) ...<Widget>[
                  TRText('$error', color: TRTextColor.danger),
                  const SizedBox(height: TRSpacing.small),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (widget.interaction?.status ==
                        ChatInteractionStatus.resolved)
                      TRText(
                        widget.interaction!.approved == true
                            ? l10n.chatApprovalAllow
                            : l10n.chatApprovalDeny,
                        variant: TRTextVariant.label,
                        color: widget.interaction!.approved == true
                            ? TRTextColor.primary
                            : TRTextColor.muted,
                      )
                    else ...<Widget>[
                      TRButton(
                        appearance: TRAppearance.ghost,
                        onPressed: _submitting || widget.hostId == null
                            ? null
                            : () => _resolve(approved: false),
                        child: TRText.inherit(l10n.chatApprovalDeny),
                      ),
                      const SizedBox(width: TRSpacing.small),
                      TRButton(
                        intent: TRIntent.primary,
                        onPressed: _submitting || widget.hostId == null
                            ? null
                            : () => _resolve(approved: true),
                        child: TRText.inherit(l10n.chatApprovalAllow),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final preview = approval.preview;
    if (preview == null || preview.isEmpty) {
      return ChatCodeBlock(
        text: const JsonEncoder.withIndent('  ').convert(approval.arguments),
        maxLines: 12,
      );
    }
    // Permission chrome is host-owned. Plugins may supply inert preview text,
    // but they cannot select executable widgets or bypass this confirmation.
    return ChatCodeBlock(text: preview, maxLines: 12);
  }

  void _resolve({required bool approved}) => unawaited(() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(
            conversationControllerProvider(
              widget.hostId!,
              approval.sessionId,
            ).notifier,
          )
          .resolveApproval(approval.id, approved: approved);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }());
}
