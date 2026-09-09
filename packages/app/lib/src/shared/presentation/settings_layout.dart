import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Returns the settings shell's adaptive class without classifying an inner
/// pane's constraints.
///
/// Unified Settings supplies [TRAdaptiveLayoutScope]. Standalone task routes
/// and focused widget hosts fall back to the logical root viewport. This keeps
/// the window policy from mistaking an already-allocated pane for a smaller
/// window.
TRAdaptiveWidthClass settingsAdaptiveWidthClassOf(BuildContext context) =>
    TRAdaptiveLayoutScope.maybeOf(context)?.widthClass ??
    TRAdaptiveWidthClass.fromWidth(MediaQuery.sizeOf(context).width);

/// Whether a list-detail host shows its collection and detail side by side.
///
/// Below this the detail covers the collection, which makes it a destination
/// of its own. Callers outside [SettingsListDetailHost] must ask here rather
/// than repeat the comparison, or Up would offer to close a detail that is
/// already sitting next to its collection.
bool settingsListDetailIsSplit(TRAdaptiveWidthClass widthClass) =>
    widthClass == TRAdaptiveWidthClass.large ||
    widthClass == TRAdaptiveWidthClass.extraLarge;

/// Navigation the Settings shell owns on behalf of the destination it renders.
///
/// A compact destination draws the only page header, so it needs the shell's
/// up action. The shell owns where up leads — the compact ladder of detail,
/// daemon categories, home, and then out of the task, or simply out of the
/// task once the sidebar makes every category reachable — so destinations
/// never reimplement it.
class SettingsShellScope extends InheritedWidget {
  /// Publishes the shell's up action to its destinations.
  const new({required this.onBack, required super.child, super.key});

  /// Moves one step up the Settings stack.
  final VoidCallback onBack;

  /// Returns the enclosing scope, or null outside the Settings shell.
  static SettingsShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsShellScope>();

  @override
  bool updateShouldNotify(SettingsShellScope oldWidget) =>
      onBack != oldWidget.onBack;
}

/// One Settings destination together with the header that identifies it.
///
/// Below the compact breakpoint the Settings shell renders no chrome of its
/// own, so this draws the page header bar carrying the destination's identity,
/// actions, and up action. The header therefore moves with the navigation
/// stack instead of stacking a static title above a pane title. From medium
/// widths up the sidebar already reports the destination, so this keeps the
/// established [TRPaneHeader] aligned to the pane's content rail.
///
/// A destination header carries a title and its actions and nothing else. The
/// supporting line these headers used to show — a count, a source path, a
/// connection status — read as clutter once the header became the page's own
/// chrome, and every one of those values is still reported by the body below.
///
/// [actions] is typed to square icon controls, so the header is one control
/// tall at every width. An action that needs a word rather than a glyph goes
/// where the words are: [formActions] when it commits or abandons the whole
/// destination, or `SettingsSection.action` when it acts on one section.
class SettingsDestinationScaffold extends StatelessWidget {
  /// Creates a destination whose header adapts to the shell's width class.
  const new({
    required this.title,
    required this.child,
    this.actions = const <TRIconButton>[],
    this.formActions = const <Widget>[],
    this.contentMaxWidth,
    super.key,
  });

  /// The destination's primary heading.
  final Widget title;

  /// Icon actions associated with the whole destination.
  final List<TRIconButton> actions;

  /// Commit and cancel actions for the destination, primary last.
  ///
  /// Rendered below the body rather than inside it, so a long form cannot
  /// scroll its own primary action out of reach.
  final List<Widget> formActions;

  /// Optional cap shared with a body that centres its readable content.
  final double? contentMaxWidth;

  /// The destination's body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact =
        settingsAdaptiveWidthClassOf(context) == TRAdaptiveWidthClass.compact;
    final onBack = SettingsShellScope.maybeOf(context)?.onBack;
    // A destination that has been pushed over stays mounted so it can paint
    // its own chrome through the transition. Only the destination on top is
    // the app's up action, so only it carries that identity.
    final active = ModalRoute.of(context)?.isCurrent ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (compact)
          TinestPageHeaderBar(
            header: TinestPageHeader(
              title: title,
              leading: onBack == null
                  ? null
                  : TRIconButton(
                      key: active
                          ? const ValueKey<String>('settings-back-button')
                          : null,
                      appearance: TRAppearance.ghost,
                      label: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: onBack,
                      icon: Icon(TinestIcons.backFor(context)),
                    ),
              actions: actions,
            ),
          )
        else
          TRPaneHeader(
            title: title,
            actions: actions,
            contentMaxWidth: contentMaxWidth,
          ),
        Expanded(child: child),
        if (formActions.isNotEmpty)
          SettingsFormActions(
            contentMaxWidth: contentMaxWidth,
            children: formActions,
          ),
      ],
    );
  }
}

/// The commit and cancel actions belonging to one settings destination.
///
/// Pinned below the destination's scrolling body instead of placed inside it.
/// A primary action that scrolls away is one the user has to go looking for
/// after editing the field that made it matter, and a caller that finds it by
/// key taps nothing at all when it sits outside the viewport.
///
/// [TRAppShell.resizeToAvoidBottomInset] keeps the shell above the software
/// keyboard, so this needs no inset handling of its own.
class SettingsFormActions extends StatelessWidget {
  /// Creates a destination action bar showing [children] trailing.
  const new({required this.children, this.contentMaxWidth, super.key});

  /// Actions in reading order, primary last.
  final List<Widget> children;

  /// Optional cap shared with the body and header above it.
  final double? contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    // A Wrap rather than a Row: unlike the page header, this bar is allowed
    // to take a second line, and at a large text scale two labelled buttons
    // do not fit one. Trailing alignment keeps the primary action under the
    // reader's thumb whether or not it wraps.
    final content = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TRSpacing.small,
      runSpacing: TRSpacing.small,
      children: children,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const TRSeparator(variant: TRSeparatorVariant.muted),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TRSpacing.extraLarge,
            vertical: TRSpacing.large,
          ),
          // The same cap the header and body use, so the bar's trailing edge
          // lines up with the fields it commits rather than with the window.
          child: contentMaxWidth == null
              ? content
              : Align(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth!),
                    child: SizedBox(width: double.infinity, child: content),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The product-owned content slots supplied to the adaptive pane scaffold.
enum SettingsPaneSlot {
  /// The primary collection or category content.
  collection,

  /// The secondary editor, creator, or item detail.
  detail,
}

/// Read-only navigation state shared by one list-detail settings feature.
///
/// Typed routes own categories. A feature controller owns only its local
/// detail stack. Flutter Navigator and Page own its route lifecycle.
abstract interface class SettingsPaneCoordinator implements Listenable {
  /// Destinations stacked above the collection, innermost last.
  ///
  /// Entries are route identities and must compare by value, because the host
  /// keys one Page per entry. Modelling a nested destination as a deeper entry
  /// rather than a different single entry is what makes returning from it a
  /// pop: a changed key would be a removal plus a push, which plays the
  /// forward transition and rebinds the collection's secondary animation.
  List<Object> get detailStack;

  /// Whether the feature currently has a detail or create destination.
  bool get hasDetail;

  /// Whether a desktop collection may choose its first item automatically.
  ///
  /// This is consumed after the first automatic selection or any explicit
  /// navigation. Returning from a detail therefore leaves the collection
  /// visible instead of immediately reopening its first item.
  bool get canAutoSelect;

  /// Returns to whatever encloses the innermost detail destination.
  void popDetail();

  /// Drops [destination] once its route has left the Navigator.
  ///
  /// A destination that was replaced rather than popped is already absent, so
  /// this leaves the stack alone and a replacement is never mistaken for Back.
  void removeDetail(Object destination);

  /// Returns the feature to its collection destination.
  void showCollection();

  /// Clears local navigation for a different route identity.
  void reset();
}

/// Shares the initial desktop selection contract across Settings features.
abstract class SettingsPaneCoordinatorBase extends ChangeNotifier
    implements SettingsPaneCoordinator {
  bool _autoSelectionConsumed = false;

  @override
  bool get hasDetail => detailStack.isNotEmpty;

  @override
  bool get canAutoSelect => !hasDetail && !_autoSelectionConsumed;

  /// Consumes and admits the first desktop selection for this route identity.
  @protected
  bool consumeInitialSelection() {
    if (!canAutoSelect) return false;
    _autoSelectionConsumed = true;
    return true;
  }

  /// Prevents later rebuilds from interpreting explicit navigation as entry.
  @protected
  void consumeExplicitNavigation() {
    _autoSelectionConsumed = true;
  }

  /// Re-enables initial selection after the route identity changes.
  @protected
  void resetInitialSelection() {
    _autoSelectionConsumed = false;
  }

  /// Leaves the only detail level, which is the collection.
  ///
  /// Most features offer their detail destinations as siblings of one another,
  /// so there is nothing between them and the collection. A feature that nests
  /// one destination inside another overrides this and [removeDetail].
  @override
  void popDetail() => showCollection();

  @override
  void removeDetail(Object destination) {
    // A destination that was replaced rather than popped has already left the
    // stack, so its route leaving is not the user going back.
    if (!detailStack.contains(destination)) return;
    showCollection();
  }
}

/// A typed, product-local selection controller for one settings collection.
class SettingsPaneController<T extends Object>
    extends SettingsPaneCoordinatorBase {
  /// Creates a typed settings pane controller.
  new();

  T? _destination;

  /// The selected item or create destination, when one is active.
  T? get selection => _destination;

  /// Sibling destinations, so the stack is never deeper than one entry.
  @override
  List<Object> get detailStack =>
      _destination == null ? const <Object>[] : <Object>[_destination!];

  /// Shows [destination] as the initial desktop detail, at most once per
  /// route identity.
  void showInitialDetail(T destination) {
    if (!consumeInitialSelection()) return;
    _destination = destination;
    notifyListeners();
  }

  /// Shows the detail represented by [destination].
  void showDetail(T destination) {
    consumeExplicitNavigation();
    if (_destination == destination) return;
    _destination = destination;
    notifyListeners();
  }

  @override
  void showCollection() {
    consumeExplicitNavigation();
    if (_destination == null) return;
    _destination = null;
    notifyListeners();
  }

  @override
  void reset() {
    final hadDetail = _destination != null;
    resetInitialSelection();
    _destination = null;
    if (hadDetail) notifyListeners();
  }
}

/// Identifies which stacked detail destination a subtree renders.
///
/// The host gives each page the destination it was built for instead of the
/// innermost one, so a route on its way out keeps rendering what the user is
/// leaving rather than whatever took its place.
///
/// Absent in the collection pane and in the empty detail slot, which is how a
/// feature tells "no destination" from one of its own.
class SettingsDetailScope extends InheritedWidget {
  /// Publishes one detail destination to the page rendering it.
  const new({required this.destination, required super.child, super.key});

  /// The route identity this subtree renders.
  final Object destination;

  /// Returns the enclosing detail destination, or null outside a detail page.
  static Object? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SettingsDetailScope>()
      ?.destination;

  @override
  bool updateShouldNotify(SettingsDetailScope oldWidget) =>
      destination != oldWidget.destination;
}

/// Renders one settings collection/detail pair with standard Page lifecycle.
///
/// Below the large width class the nested Navigator moves between collection
/// and detail across the complete content region. At large widths the
/// collection stays fixed and the same keyed Navigator moves into the detail
/// region, so only detail transitions while its State survives resizing.
///
/// The coordinator's stack is laid out one Page per entry, so a destination
/// opened from another is pushed over it and leaving it is an ordinary pop.
class SettingsListDetailHost extends StatefulWidget {
  /// Creates a routed list-detail host.
  const new({
    required this.coordinator,
    required this.collection,
    required this.detail,
    super.key,
  });

  /// Typed local detail selection owned by the feature.
  final SettingsPaneCoordinator coordinator;

  /// Collection surface.
  final Widget collection;

  /// Detail surface, including its empty-selection state.
  final Widget detail;

  @override
  State<SettingsListDetailHost> createState() => _SettingsListDetailHostState();
}

class _SettingsListDetailHostState extends State<SettingsListDetailHost> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.coordinator,
    builder: (context, _) {
      final split = settingsListDetailIsSplit(
        settingsAdaptiveWidthClassOf(context),
      );
      final stack = widget.coordinator.detailStack;
      final hasDetail = stack.isNotEmpty;
      final navigator = NavigatorPopHandler<Object?>(
        // Only intercept Back while the detail is what Back would leave. Split
        // keeps the collection beside it, so closing the detail there would
        // spend a press without changing what the user can see.
        enabled: !split && hasDetail,
        onPopWithResult: (result) =>
            _navigatorKey.currentState?.pop<Object?>(result),
        child: Navigator(
          key: _navigatorKey,
          transitionDelegate: const DefaultTransitionDelegate<void>(),
          pages: <Page<void>>[
            MaterialPage<void>(
              key: const ValueKey<String>('settings-collection-page'),
              name: 'settings-collection',
              child: TRSurface(
                child: split
                    ? hasDetail
                          ? const SizedBox.expand()
                          : widget.detail
                    : widget.collection,
              ),
            ),
            for (final destination in stack)
              MaterialPage<void>(
                key: ValueKey<Object>(destination),
                name: 'settings-detail',
                child: TRSurface(
                  child: SettingsDetailScope(
                    destination: destination,
                    child: widget.detail,
                  ),
                ),
              ),
          ],
          onDidRemovePage: (page) {
            // The collection page shares the Navigator but is never removed,
            // and its key is a plain string rather than a destination.
            if (page.name != 'settings-detail') return;
            if (page.key case ValueKey<Object>(:final value)) {
              widget.coordinator.removeDetail(value);
            }
          },
        ),
      );
      return TRAdaptiveListDetailLayout(
        singlePane: navigator,
        collectionPane: widget.collection,
        detailPane: navigator,
      );
    },
  );
}

/// Applies one loading, stale-data, and error policy to settings reads.
class SettingsAsyncContent<T> extends StatelessWidget {
  /// Creates a settings data boundary.
  const new({
    required this.state,
    required this.loading,
    required this.data,
    required this.error,
    super.key,
  });

  /// Current asynchronous state.
  final AsyncValue<T> state;

  /// Shape-preserving placeholder used before the first value.
  final Widget loading;

  /// Builds the usable surface from the newest available value.
  final Widget Function(T value) data;

  /// Builds a blocking error only when no value has ever loaded.
  final Widget Function(Object error, StackTrace stackTrace) error;

  @override
  Widget build(BuildContext context) {
    if (state.hasValue) {
      final child = data(state.requireValue);
      if (!state.hasError) return child;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: TRSpacing.extraLarge,
              top: TRSpacing.medium,
              right: TRSpacing.extraLarge,
            ),
            child: TRAlert(
              key: const ValueKey<String>('settings-refresh-error'),
              variant: TRStatusVariant.danger,
              title: TRText.inherit(
                AppLocalizations.of(context)
                    .settingsRefreshFailed('${state.error}'),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );
    }
    if (state.isLoading) return loading;
    return error(state.error!, state.stackTrace!);
  }
}

enum _SettingsSkeletonKind { form, collection, detail, overlay }

/// Loading placeholders that preserve the final shape of a settings surface.
///
/// The shell owns navigation and these placeholders own only the data region,
/// so an unavailable daemon or catalog never blocks category navigation.
class SettingsSkeletonLayout extends StatelessWidget {
  /// Creates a settings form placeholder.
  const new form({required this.semanticLabel, super.key})
    : _kind = _SettingsSkeletonKind.form;

  /// Creates a collection-pane placeholder.
  const new collection({required this.semanticLabel, super.key})
    : _kind = _SettingsSkeletonKind.collection;

  /// Creates a detail-pane placeholder.
  const new detail({required this.semanticLabel, super.key})
    : _kind = _SettingsSkeletonKind.detail;

  /// Creates a compact overlay placeholder.
  const new overlay({required this.semanticLabel, super.key})
    : _kind = _SettingsSkeletonKind.overlay;

  /// Accessible description announced once for the complete placeholder.
  final String semanticLabel;

  final _SettingsSkeletonKind _kind;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: true,
    liveRegion: true,
    child: ExcludeSemantics(
      child: switch (_kind) {
        _SettingsSkeletonKind.form => const _SettingsFormSkeleton(),
        _SettingsSkeletonKind.collection => const _SettingsSkeletonListPane(),
        _SettingsSkeletonKind.detail => const _SettingsSkeletonDetailPane(),
        _SettingsSkeletonKind.overlay => const _SettingsOverlaySkeleton(),
      },
    ),
  );
}

/// Returns the shape-preserving placeholder for one adaptive settings slot.
SettingsSkeletonLayout settingsPaneSkeleton(
  SettingsPaneSlot slot, {
  required String semanticLabel,
}) => switch (slot) {
  SettingsPaneSlot.collection => SettingsSkeletonLayout.collection(
    semanticLabel: semanticLabel,
  ),
  SettingsPaneSlot.detail => SettingsSkeletonLayout.detail(
    semanticLabel: semanticLabel,
  ),
};

class _SettingsFormSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SettingsScaffold(
    key: ValueKey<String>('settings-skeleton-form'),
    children: <Widget>[
      _SettingsSkeletonSection(rowCount: 2),
      _SettingsSkeletonSection(rowCount: 3),
    ],
  );
}

class _SettingsSkeletonListPane extends StatelessWidget {
  const new()
    : super(key: const ValueKey<String>('settings-skeleton-list-pane'));

  @override
  Widget build(BuildContext context) => const SettingsDestinationScaffold(
    title: TRSkeleton(width: TRMeasurements.measureSm),
    child: SettingsCollectionList(
      children: <Widget>[
        _SettingsSkeletonListRow(),
        _SettingsSkeletonListRow(),
        _SettingsSkeletonListRow(),
        _SettingsSkeletonListRow(),
      ],
    ),
  );
}

class _SettingsSkeletonListRow extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: SettingsRow.resolvedPadding(context, collection: true),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TRSkeleton(width: TRMeasurements.measureSm),
        SizedBox(height: TRSpacing.extraSmall),
        TRSkeleton(width: TRMeasurements.measureMd),
      ],
    ),
  );
}

/// A scrollable collection pane whose rows share the settings sidebar rhythm.
///
/// The pane boundary supplies the outer inset while collection rows add the
/// same token-sized inline padding used by tree navigation. This keeps
/// selected, hovered, and focused surfaces away from the pane edge while
/// aligning their content with the collection header.
class SettingsCollectionList extends StatelessWidget {
  /// Creates an inset collection with token-based spacing between [children].
  const new({required this.children, super.key});

  /// Rows and collection-local headings shown in display order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(
      horizontal: TRSpacing.medium,
      vertical: TRSpacing.medium,
    ),
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    separatorBuilder: (context, index) =>
        const SizedBox(height: TRSpacing.extraSmall),
  );
}

class _SettingsSkeletonDetailPane extends StatelessWidget {
  const new()
    : super(key: const ValueKey<String>('settings-skeleton-detail-pane'));

  @override
  Widget build(BuildContext context) => const SettingsDestinationScaffold(
    title: TRSkeleton(width: TRMeasurements.measureSm),
    contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
    child: _SettingsFormSkeleton(),
  );
}

class _SettingsSkeletonSection extends StatelessWidget {
  const new({required this.rowCount});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final compact =
        settingsAdaptiveWidthClassOf(context) == TRAdaptiveWidthClass.compact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The placeholder takes the shape the content will, card and all, so
        // the page does not jump sideways the moment it loads.
        Padding(
          padding: compact
              ? EdgeInsets.symmetric(
                  horizontal: SettingsRow.resolvedPadding(context)
                      .resolve(Directionality.of(context))
                      .left,
                )
              : EdgeInsets.zero,
          child: const TRSkeleton(width: TRMeasurements.measureSm),
        ),
        const SizedBox(height: TRSpacing.small),
        _SettingsGroup(
          boxed: !compact,
          children: <Widget>[
            for (var index = 0; index < rowCount; index++)
              const _SettingsSkeletonListRow(),
          ],
        ),
      ],
    );
  }
}

class _SettingsOverlaySkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey<String>('settings-skeleton-overlay'),
    width: TRMeasurements.overlayWidthMd,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TRSkeleton(width: TRMeasurements.measureSm),
        SizedBox(height: TRSpacing.large),
        TRSkeleton(shape: TRSkeletonShape.rectangle),
        SizedBox(height: TRSpacing.small),
        TRSkeleton(shape: TRSkeletonShape.rectangle),
        SizedBox(height: TRSpacing.small),
        TRSkeleton(shape: TRSkeletonShape.rectangle),
      ],
    ),
  );
}

/// The scroll container every settings pane uses.
///
/// Page padding, content width, and the gap between sections live here rather
/// than in each page. Eight pages that each laid out their own `ListView` were
/// free to drift apart, and every one of them did.
class SettingsScaffold extends StatefulWidget {
  /// Creates a settings pane showing [children] as its sections.
  const new({required this.children, super.key});

  /// Sections shown in order.
  final List<Widget> children;

  @override
  State<SettingsScaffold> createState() => _SettingsScaffoldState();
}

class _SettingsScaffoldState extends State<SettingsScaffold> {
  double _bottomInset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (nextBottomInset > _bottomInset) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final focusContext = FocusManager.instance.primaryFocus?.context;
        if (focusContext != null) {
          var targetContext = focusContext;
          focusContext.visitAncestorElements((element) {
            if (element.widget is TRTextField ||
                element.widget is TRNumberField ||
                element.widget is TRTextarea) {
              targetContext = element;
              return false;
            }
            return true;
          });
          Scrollable.ensureVisible(
            targetContext,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      });
    }
    _bottomInset = nextBottomInset;
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        settingsAdaptiveWidthClassOf(context) == TRAdaptiveWidthClass.compact;
    return ListView(
      // A phone spends every pixel of its width on the rows. A page margin
      // there costs both edges and buys nothing, because each row already
      // draws its own inline inset; a wide window has the room and reads
      // better with the column held off the pane edges.
      padding: compact
          // No horizontal inset at all rather than a zero one: the rows run
          // to both edges and supply the only rail.
          ? const EdgeInsets.only(
              top: TRSpacing.small,
              bottom: TRSpacing.fourExtraLarge,
            )
          : const EdgeInsets.fromLTRB(
              TRSpacing.extraLarge,
              TRSpacing.extraLarge,
              TRSpacing.extraLarge,
              TRSpacing.fourExtraLarge,
            ),
      children: <Widget>[
        // Each section stays its own list child rather than sharing one.
        // Folding them into a single child builds every section eagerly, so
        // a finder resolves a section that is scrolled out of view and a tap
        // on it lands outside the viewport and quietly hits nothing.
        for (final (index, child) in widget.children.indexed)
          Padding(
            // tinyrack-check-ignore-next-line tokens/no-literal -- only later sections receive the inter-section token gap
            padding: index > 0
                ? EdgeInsets.only(
                    top: compact
                        ? TRSpacing.extraLarge
                        : TRSpacing.twoExtraLarge,
                  )
                : EdgeInsets.zero,
            child: Align(
              // Centred, so a wide window keeps the column balanced rather
              // than stranding it against one edge with a growing void.
              // Below the cap the column fills the pane and this is a no-op.
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
                ),
                child: child,
              ),
            ),
          ),
      ],
    );
  }
}

/// One optionally titled group of settings.
///
/// A wide window frames the group in a card, the way a settings pane reads
/// beside other panes. A phone drops the card and runs the rows to both edges:
/// a border and a page margin there cost width the rows need, and stacking a
/// card per setting is what made a short list of preferences scroll.
class SettingsSection extends StatelessWidget {
  /// Creates a section whose [children] are [SettingsRow]s sharing one group.
  const new({
    required this.children,
    this.title,
    this.description,
    this.action,
    this.banner,
    this.footer,
    super.key,
  }) : _boxed = true;

  /// Creates a section whose [children] are form controls that draw their own
  /// frame, laid out without a surrounding card.
  ///
  /// A multi-line editor cannot sit in a trailing rail, so it keeps the
  /// stacked label-above-control shape `TRField` defines instead of being
  /// forced into a row.
  const new form({
    required this.children,
    this.title,
    this.description,
    this.action,
    this.banner,
    this.footer,
    super.key,
  }) : _boxed = false;

  /// Optional section heading.
  ///
  /// A task page may already name the form in its pane header. Omitting this
  /// heading prevents the same title from being announced and drawn twice.
  final String? title;

  /// Optional supporting line under the heading.
  final String? description;

  /// Optional action rendered opposite the heading.
  final Widget? action;

  /// Optional status banner shown between the heading and the content.
  ///
  /// A save result, a connection failure, or a parse diagnostic belongs to its
  /// section rather than to the page, so it sits inside the section's spacing
  /// instead of being stacked above it as another top-level block.
  final Widget? banner;

  /// Optional note shown under the group.
  ///
  /// Where a setting needs explaining, the explanation belongs to the group
  /// rather than to each row. A sentence repeated under every label is what
  /// turned one line into three and pushed the next setting off the screen,
  /// and it says the same thing three times besides.
  final String? footer;

  /// Section content.
  final List<Widget> children;

  /// Whether the content shares one card.
  final bool _boxed;

  @override
  Widget build(BuildContext context) {
    final hasHeading = title != null || action != null;
    final hasDescription = description != null;
    final hasBanner = banner != null;
    final hasPreamble = hasHeading || hasDescription || hasBanner;
    final compact =
        settingsAdaptiveWidthClassOf(context) == TRAdaptiveWidthClass.compact;
    // A card supplies the rail its rows read on. Without one, the copy around
    // the group has to take the same inline inset the rows draw at, or the
    // heading, the rows, and the note under them each start somewhere else.
    final rail = compact
        ? EdgeInsets.symmetric(
            horizontal: SettingsRow.resolvedPadding(context)
                .resolve(Directionality.of(context))
                .left,
          )
        : EdgeInsets.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasPreamble)
          Padding(
            padding: rail,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // A Wrap rather than a Row: on a narrow window, or at a large
                // text scale, a heading and its action do not fit on one line.
                // Wrapping is what keeps the action from overflowing, and
                // spaceBetween still puts it against the trailing edge
                // whenever the two do fit.
                if (hasHeading)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TRSpacing.large,
                    runSpacing: TRSpacing.small,
                    children: <Widget>[
                      if (title case final title?)
                        // Section titles are subordinate to the pane header.
                        // The smaller public heading role also keeps a long
                        // word intact when the system text scale is enlarged
                        // on a compact pane.
                        TRText(title, variant: TRTextVariant.headingSm),
                      ?action,
                    ],
                  ),
                if (description case final description?) ...<Widget>[
                  if (hasHeading) const SizedBox(height: TRSpacing.medium),
                  TRText(
                    description,
                    variant: TRTextVariant.bodySm,
                    color: TRTextColor.muted,
                  ),
                ],
                if (banner case final banner?) ...<Widget>[
                  if (hasHeading || hasDescription)
                    const SizedBox(height: TRSpacing.medium),
                  banner,
                ],
              ],
            ),
          ),
        if (hasPreamble) const SizedBox(height: TRSpacing.small),
        if (_boxed)
          _SettingsGroup(boxed: !compact, children: children)
        else
          Padding(
            // A form control draws its own frame, so it needs the rail even
            // where a boxed group hands one to its rows.
            padding: rail,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (index, child) in children.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(height: TRSpacing.large),
                  child,
                ],
              ],
            ),
          ),
        if (footer case final footer?) ...<Widget>[
          const SizedBox(height: TRSpacing.small),
          Padding(
            padding: rail,
            child: TRText(
              footer,
              variant: TRTextVariant.bodySm,
              color: TRTextColor.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// The rows of one [SettingsSection], framed or plain.
///
/// Boxed, the card draws the group's boundary and its dividers run edge to
/// edge inside it. Plain, there is no boundary to draw against, so each
/// divider starts at the rail its rows read on and runs to the far edge —
/// the shape that tells a reader the rows belong together without spending
/// width on a border.
class _SettingsGroup extends StatelessWidget {
  const new({required this.boxed, required this.children});

  final bool boxed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, child) in children.indexed) ...<Widget>[
          if (index > 0) _divider(context),
          child,
        ],
      ],
    );
    return boxed ? TRCard(padding: TRCardPadding.none, child: rows) : rows;
  }

  Widget _divider(BuildContext context) {
    // Muted, so a divider matches the card's own border rather than the
    // weight a control draws at, which is what the default variant is for.
    const separator = TRSeparator(variant: TRSeparatorVariant.muted);
    if (boxed) return separator;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: SettingsRow.resolvedPadding(context)
            .resolve(Directionality.of(context))
            .left,
      ),
      child: separator,
    );
  }
}

/// Selects where a setting's control sits relative to its label.
///
/// Neither value depends on the width the row happens to get. A control that
/// moved below its label only on a narrow window meant one setting had two
/// shapes, and which one a reader saw was decided by the window rather than by
/// the setting: the same screen read as a list on a desktop and as a stack of
/// forms on a phone. A control that cannot usefully shrink says so once, here.
enum SettingsControlLayout {
  /// Keeps the control trailing its label at every width.
  inline,

  /// Places the control below the label at the row's full width, at every
  /// width.
  ///
  /// For controls a reader types or drags in, which are unusable once they
  /// are squeezed into what a label leaves over.
  stacked,
}

/// One setting: its description leading, its control trailing or below.
///
/// Every switch, checkbox, select, button, and single-line input in settings
/// goes through here, so the inset a setting draws at is decided once. The
/// padding is deliberately not overridable: rows that could set their own were
/// how one card ended up with two alignment lines.
class SettingsRow extends StatelessWidget {
  /// Creates a settings row.
  const new({
    required this.title,
    this.control,
    this.controlLayout = SettingsControlLayout.inline,
    this.controlOwnsFocus = false,
    this.description,
    this.leading,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.wrapsDescription = false,
    this.unboundedDescription = false,
    this.flush = false,
    super.key,
  }) : _collection = false;

  /// Creates a row inside a [SettingsCollectionList].
  ///
  /// Its selected, hover, and focus surface is inset by the surrounding list,
  /// while its content remains aligned with [TRPaneHeader].
  const new collection({
    required this.title,
    this.control,
    this.controlLayout = SettingsControlLayout.inline,
    this.controlOwnsFocus = false,
    this.description,
    this.leading,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.wrapsDescription = false,
    this.unboundedDescription = false,
    super.key,
  }) : flush = false,
       _collection = true;

  /// Primary label.
  final Widget title;

  /// Optional supporting text under the label.
  final Widget? description;

  /// Optional leading visual.
  final Widget? leading;

  /// Optional trailing control.
  final Widget? control;

  /// How [control] responds when the row's readable copy width is constrained.
  final SettingsControlLayout controlLayout;

  /// Whether [control] is the row's only tab stop.
  ///
  /// Set this whenever [onTap] only repeats what [control] already does, so
  /// one setting costs one Tab press. See [TinestListRow.controlOwnsFocus].
  final bool controlOwnsFocus;

  /// Invoked when the row is activated.
  final VoidCallback? onTap;

  /// Whether the row accepts activation.
  final bool enabled;

  /// Whether the row reads as selected.
  final bool selected;

  /// Whether the description may occupy a second line.
  final bool wrapsDescription;

  /// Whether the description may run to as many lines as it needs.
  ///
  /// For a description that is prose rather than a status line: two lines cut
  /// it mid-sentence on a narrow window.
  final bool unboundedDescription;

  /// Whether the surrounding container already supplies the inline inset.
  ///
  /// A dialog pads its own content, so a row inside one would otherwise sit a
  /// step further in than the fields above it. Collection panes use the
  /// explicit [SettingsRow.collection] constructor instead, because their
  /// outer inset also defines the selected and focus surface boundary.
  final bool flush;

  final bool _collection;

  /// The inset every settings row draws its content at.
  static const contentPadding = EdgeInsets.symmetric(
    horizontal: TRSpacing.large,
    vertical: TRSpacing.medium,
  );

  /// The inset a row draws at inside a container that supplies its own.
  static const flushPadding = EdgeInsets.symmetric(vertical: TRSpacing.medium);

  /// Content inset used after the collection supplies its outer pane inset.
  static const collectionContentPadding = EdgeInsets.symmetric(
    horizontal: TRSpacing.medium,
    vertical: TRSpacing.medium,
  );

  /// Resolves row insets from the inherited UI density.
  ///
  /// Product composites that align custom content with a settings row use
  /// this instead of freezing the standard-density constants above.
  static EdgeInsetsGeometry resolvedPadding(
    BuildContext context, {
    bool flush = false,
    bool collection = false,
  }) {
    final comfortable = TRUiDensityScope.of(context) == TRUiDensity.comfortable;
    final vertical = comfortable ? TRSpacing.large : TRSpacing.medium;
    if (flush) return EdgeInsets.symmetric(vertical: vertical);
    return EdgeInsets.symmetric(
      horizontal: collection ? TRSpacing.medium : TRSpacing.large,
      vertical: vertical,
    );
  }

  EdgeInsetsGeometry _padding(BuildContext context) =>
      resolvedPadding(context, flush: flush, collection: _collection);

  @override
  Widget build(BuildContext context) => TinestListRow(
    contentPadding: _padding(context),
    controlOwnsFocus: controlOwnsFocus,
    enabled: enabled,
    hoverEnabled: false,
    isThreeLine: wrapsDescription || unboundedDescription,
    // A description that is allowed to wrap is prose, and prose that stops at
    // two lines stops mid-sentence. It runs to the lines it needs at every
    // width rather than only on the narrow window that made it obvious.
    unboundedSubtitle: unboundedDescription || wrapsDescription,
    leading: leading,
    onTap: onTap,
    selected: selected,
    selectionAppearance: _collection
        ? TinestListRowSelectionAppearance.navigation
        : TinestListRowSelectionAppearance.standard,
    subtitle: description,
    title: title,
    trailing: control,
    trailingLayout:
        control != null && controlLayout == SettingsControlLayout.stacked
        ? TinestListRowTrailingLayout.below
        : TinestListRowTrailingLayout.inline,
  );
}

/// A consistent empty or unselected state for settings panes.
///
/// The content is intentionally centred as one compact reading group. Plain
/// `Center(child: Text(...))` states had no shared hierarchy and drifted from
/// each other as pages added icons or actions independently.
class SettingsEmptyState extends StatelessWidget {
  /// Creates a settings empty state.
  const new({
    required this.title,
    this.description,
    this.icon,
    this.action,
    super.key,
  });

  /// Primary empty-state message.
  final String title;

  /// Optional explanation or next step.
  final String? description;

  /// Optional semantic visual.
  final Widget? icon;

  /// Optional action resolving the empty state.
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(TRSpacing.extraLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: TinestLayoutMetrics.settingsEmptyStateMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final icon?) ...<Widget>[
              icon,
              const SizedBox(height: TRSpacing.medium),
            ],
            TRText(
              title,
              variant: TRTextVariant.headingSm,
              align: TRTextAlign.center,
            ),
            if (description case final description?) ...<Widget>[
              const SizedBox(height: TRSpacing.extraSmall),
              TRText(
                description,
                variant: TRTextVariant.bodySm,
                color: TRTextColor.muted,
                align: TRTextAlign.center,
              ),
            ],
            if (action case final action?) ...<Widget>[
              const SizedBox(height: TRSpacing.large),
              action,
            ],
          ],
        ),
      ),
    ),
  );
}

/// A blocking Settings load failure with one explicit recovery action.
///
/// Settings providers disable automatic retry: silently replacing an error
/// with a loading skeleton hides the failure and makes every page feel
/// different. This state keeps the failure visible until the user retries.
class SettingsErrorState extends StatelessWidget {
  /// Creates a shared Settings error state.
  const new({required this.error, required this.onRetry, super.key});

  /// Failure reported by the Settings provider.
  final Object error;

  /// Explicitly starts another load attempt.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SettingsEmptyState(
    title: AppLocalizations.of(context).commonActionFailed,
    description: '$error',
    icon: const Icon(TinestIcons.error),
    action: TRButton(
      intent: TRIntent.primary,
      onPressed: onRetry,
      child: TRText.inherit(AppLocalizations.of(context).commonRetry),
    ),
  );
}

/// A list-detail collection failure that preserves the pane's normal header.
///
/// Loading, empty, populated, and failed collection panes keep the same title
/// rail, so status changes do not make the pane geometry jump. It goes through
/// [SettingsDestinationScaffold] rather than drawing [TRPaneHeader] directly:
/// a failed load on a phone otherwise showed the desktop pane header and left
/// the destination with no way back.
class SettingsCollectionErrorState extends StatelessWidget {
  /// Creates a collection header followed by a shared error state.
  const new({
    required this.title,
    required this.error,
    required this.onRetry,
    super.key,
  });

  /// Collection title shown in every state.
  final String title;

  /// Failure reported by the collection provider.
  final Object error;

  /// Explicitly starts another load attempt.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SettingsDestinationScaffold(
    title: TRText.inherit(title),
    child: SettingsErrorState(error: error, onRetry: onRetry),
  );
}

/// The shared field rhythm and width for settings dialogs.
class SettingsDialogForm extends StatelessWidget {
  /// Creates a settings dialog form.
  const new({
    required this.children,
    this.width = TRMeasurements.overlayWidthMd,
    super.key,
  });

  /// Fields, notices, and other form content in reading order.
  final List<Widget> children;

  /// Public Tinyrack overlay measurement used by this dialog.
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, child) in children.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: TRSpacing.large),
          child,
        ],
      ],
    ),
  );
}

/// The stacked selects shown above a settings pane on a narrow window.
///
/// The category, daemon, and project selects used to render at three different
/// widths and alignments because only one of them was told to fill the pane.
/// The width reaches each control through [builder] rather than through a
/// stretching parent: a `TRSelect` keeps an intrinsic-width trigger unless it
/// is given a width, so stretching only the surrounding box leaves a narrow
/// trigger sitting in a wide empty field.
class SettingsCompactToolbar extends StatelessWidget {
  /// Creates a compact settings toolbar whose controls fill the given width.
  const new({required this.builder, super.key});

  /// Builds the controls, in order, for the width available to them.
  final List<Widget> Function(double width) builder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TRSpacing.extraLarge,
      TRSpacing.large,
      TRSpacing.extraLarge,
      TRSpacing.medium,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final children = builder(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (index, child) in children.indexed) ...<Widget>[
              if (index > 0) const SizedBox(height: TRSpacing.small),
              child,
            ],
          ],
        );
      },
    ),
  );
}
