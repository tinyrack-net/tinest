import 'package:app/l10n/gen/app_localizations.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Longest failure detail a toast repeats back to the user.
///
/// The card clips a long description to a few lines, but the whole string still
/// reaches the semantics tree, so a screen reader would otherwise read out an
/// entire daemon stack trace. Trimming keeps what is announced as short as what
/// is shown; the full text belongs in a log or a details dialog.
const _maxDescriptionCharacters = 240;

/// Queue behind the application's toast region.
final appToastControllerProvider = Provider<TRToastController>((ref) {
  final controller = TRToastController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Reports the results of user actions.
final toastMessengerProvider = Provider<ToastMessenger>((ref) {
  final messenger = ToastMessenger(ref.watch(appToastControllerProvider));
  ref.onDispose(messenger.retire);
  return messenger;
});

/// Reports the outcome of a user action as a transient notification.
///
/// Holds no [BuildContext] on purpose: a result still reaches the user when the
/// screen that started the action has already closed, which is exactly the case
/// a form that saves and then navigates away could never report. Callers must
/// therefore read their [AppLocalizations] strings before awaiting, the way the
/// settings forms already do.
class ToastMessenger {
  /// Reports through the queue the region is rendering.
  new(this._controller);

  final TRToastController _controller;
  bool _retired = false;

  /// Stops reporting, because the queue behind this messenger is gone.
  ///
  /// An action can outlive the whole application scope — a shutdown while a
  /// write is in flight — and the result then arrives with nothing left to
  /// show it on. Answering that with a disposed-notifier crash would turn a
  /// successful action into a failed one.
  void retire() => _retired = true;

  /// Reports an action that finished and left nothing on screen to show for it.
  ///
  /// An action whose result is already visible — a theme that just changed, a
  /// row that just disappeared — does not need one of these.
  void success(String title, {String? description, String? id}) => _show(
    title: title,
    description: description,
    variant: TRStatusVariant.success,
    id: id,
  );

  /// Reports information that explains the result of a user action.
  void info(String title, {String? description, String? id}) => _show(
    title: title,
    description: description,
    variant: TRStatusVariant.info,
    id: id,
  );

  /// Reports an action that could not complete, describing [error] if given.
  void failure(String title, {Object? error, String? id}) => _show(
    title: title,
    description: error == null ? null : _describe(error),
    variant: TRStatusVariant.danger,
    id: id,
  );

  /// Runs [action], reports the outcome, and answers whether it completed.
  ///
  /// The answer is what lets a caller decide to close a form or stay on it, so
  /// a save that failed no longer navigates away as though it had worked.
  /// Passing an [id] makes repeats of the same action replace their own report
  /// rather than stack a new one for every attempt.
  Future<bool> run(
    Future<void> Function() action, {
    required String failure,
    String? success,
    String? id,
  }) async {
    try {
      await action();
    } on Object catch (error) {
      // Deliberately broad: this is the boundary that turns any failed action
      // into something the user can see, and a failure it declined to catch
      // would go back to being silent.
      _show(
        title: failure,
        description: _describe(error),
        variant: TRStatusVariant.danger,
        id: id,
      );
      return false;
    }
    if (success != null) {
      _show(title: success, variant: TRStatusVariant.success, id: id);
    }
    return true;
  }

  void _show({
    required String title,
    required TRStatusVariant variant,
    String? description,
    String? id,
  }) {
    if (_retired) return;
    _controller.show(
      TRToastData(
        title: TRText.inherit(title),
        description: description == null ? null : TRText.inherit(description),
        variant: variant,
        id: id,
      ),
    );
  }

  /// The part of [error] worth repeating to the user.
  ///
  /// A daemon failure already carries a written explanation; anything else has
  /// only its own description, which at least names what went wrong.
  String _describe(Object error) => switch (error) {
    TinestClientException(:final message) => _trim(message),
    _ => _trim('$error'),
  };

  String _trim(String detail) {
    final collapsed = detail.trim();
    if (collapsed.length <= _maxDescriptionCharacters) return collapsed;
    return '${collapsed.substring(0, _maxDescriptionCharacters).trimRight()}…';
  }
}

/// Mounts the application's toast region above [child].
///
/// Sits above the router so a report outlives the route that produced it, and
/// below [Localizations] so its accessible name follows the chosen language.
///
/// Reports land at the top of the window rather than the default bottom-end
/// corner. The bottom-end corner is where this application puts the control a
/// report most often follows: a settings form's Save, the composer's send. A
/// toast there covers the button that raised it, so the press that comes after
/// a report lands on the report instead.
class TinestToastScope extends ConsumerWidget {
  /// Creates the scope around [child].
  const new({required this.child, super.key});

  /// Content the toasts are drawn over.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TRToastRegion(
    controller: ref.watch(appToastControllerProvider),
    placement: TRToastPlacement.topEnd,
    semanticLabel: AppLocalizations.of(context).toastRegionLabel,
    child: child,
  );
}
