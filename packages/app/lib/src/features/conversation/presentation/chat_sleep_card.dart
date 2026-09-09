import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// How often the countdown redraws while a sleep is running.
const Duration _tick = Duration(milliseconds: 500);

/// Shows a running `sleep` call as a countdown.
///
/// The tool result only arrives once the wait ends, so the progress is derived
/// entirely on the client from the request's own timestamp. That also keeps it
/// correct across a reconnect: the elapsed time is recomputed, never counted.
class ChatSleepCard extends StatefulWidget {
  /// Creates a sleep card.
  const new({required this.sleep, super.key});

  /// The sleep call this card renders.
  final ChatSleep sleep;

  @override
  State<ChatSleepCard> createState() => _ChatSleepCardState();
}

class _ChatSleepCardState extends State<ChatSleepCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ChatSleepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Runs a ticker only while the wait is still in progress.
  void _syncTimer() {
    if (widget.sleep.isRunning) {
      _timer ??= Timer.periodic(_tick, (_) => setState(() {}));
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = widget.sleep.duration;
    final elapsed = widget.sleep.isRunning
        ? DateTime.now().toUtc().difference(widget.sleep.startedAt)
        : total;
    final clamped = Duration(
      milliseconds: elapsed.inMilliseconds.clamp(0, total.inMilliseconds),
    );
    final remaining = total - clamped;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TRSpacing.extraSmall),
      child: TRCard(
        key: const ValueKey<String>('chat-sleep-card'),
        padding: TRCardPadding.none,
        child: Padding(
          padding: const EdgeInsets.all(TRSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TRText(
                widget.sleep.reason ?? l10n.chatSleepWaiting,
                variant: TRTextVariant.label,
              ),
              const SizedBox(height: TRSpacing.small),
              TRProgress(
                value: clamped.inMilliseconds.toDouble(),
                max: total.inMilliseconds.toDouble(),
                label: l10n.chatSleepWaiting,
              ),
              const SizedBox(height: TRSpacing.threeExtraSmall),
              TRText(
                widget.sleep.isRunning
                    ? l10n.chatSleepRemaining(_seconds(remaining))
                    : l10n.chatSleepDone(_seconds(total)),
                key: const ValueKey<String>('chat-sleep-status'),
                variant: TRTextVariant.bodySm,
                color: TRTextColor.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rounds up, so a wait never reads as "0s" while it is still going.
  static int _seconds(Duration duration) =>
      (duration.inMilliseconds / 1000).ceil();
}
