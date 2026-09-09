import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/conversation/application/composer_suggestions.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/composer_trigger.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_suggestions_overlay.dart';
import 'package:app/src/features/conversation/presentation/widgets/session_composer.dart';
import 'package:app/src/shared/domain/fuzzy_match.dart';
import 'package:app/src/shared/presentation/blocked_control.dart';
import 'package:app/src/shared/presentation/model_picker.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:dropwell/dropwell.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/src/internal/focus_source.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  const inputKey = ValueKey<String>('session-composer-input');
  const sendKey = ValueKey<String>('session-composer-send');
  const stopKey = ValueKey<String>('session-composer-stop');

  testWidgets(
    'mobile composer input and send action remain above the keyboard',
    (tester) async {
      const viewport = Size(390, 760);
      const keyboardHeight = 300.0;
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _pageHarness(
          viewInsets: const EdgeInsets.only(bottom: keyboardHeight),
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.showKeyboard(find.byKey(inputKey));
      await tester.pumpAndSettle();

      final keyboardTop = viewport.height - keyboardHeight;
      expect(
        tester.getRect(find.byKey(inputKey)).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(
        tester.getRect(find.byKey(sendKey)).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__soft_keyboard_visibility__widget'],
  );

  testWidgets(
    'Enter sends, Shift+Enter opens a line, and touch platforms only tap',
    tags: const <String>[
      'feature_test__turn_execution__widget',
      // Exact executable tag required by the typed UI manifest.
      // ignore: lines_longer_than_80_chars
      'ui_variant__conversation_timeline__desktop_light_korean_keyboard_online__widget',
    ],
    (tester) async {
      for (final platform in <TargetPlatform>[
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.android,
      ]) {
        final sends = platform != TargetPlatform.android;
        final submitted = <String>[];
        await tester.pumpWidget(
          _harness(
            platform: platform,
            composer: SessionComposer(
              // A fresh composer per platform, so no text or focus carries
              // over from the previous run.
              key: ValueKey<TargetPlatform>(platform),
              enabled: true,
              onSubmit: (submission) => submitted.add(submission.text),
              bar: _bar(),
            ),
          ),
        );
        // MaterialApp animates between themes and only swaps `platform` at
        // the halfway point, so the new platform is not in effect until the
        // transition finishes.
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), 'first');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          submitted,
          sends ? <String>['first'] : isEmpty,
          reason: 'Enter on $platform',
        );

        // Shift+Enter belongs to the text field on every platform.
        await tester.enterText(find.byKey(inputKey), 'second');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(
          submitted,
          sends ? <String>['first'] : isEmpty,
          reason: 'Shift+Enter on $platform',
        );

        // The button is the way in on a touch keyboard, and still works
        // everywhere else.
        await tester.tap(find.byKey(sendKey));
        await tester.pumpAndSettle();
        expect(submitted.last, 'second', reason: 'send button on $platform');
      }
    },
  );

  testWidgets(
    'an unfinished composition never sends on the Enter that ends it',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (submission) => submitted.add(submission.text),
            bar: _bar(),
          ),
        ),
      );

      await tester.tap(find.byKey(inputKey));
      await tester.pump();
      final state = tester.state<EditableTextState>(find.byType(EditableText))
        ..updateEditingValue(
          const TextEditingValue(
            text: '한글',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, isEmpty);

      state.updateEditingValue(
        const TextEditingValue(
          text: '한글',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, <String>['한글']);
    },
  );

  testWidgets(
    'a running turn queues instead of locking the input',
    tags: const <String>[
      'feature_test__conversation_turn_queue__widget',
      'ui_transition__conversation_timeline__queue_prompt__widget',
    ],
    (tester) async {
      final queued = <QueuedTurn>[];
      final sent = <String>[];
      final interrupted = <String>[];
      late StateSetter refresh;
      await tester.pumpWidget(
        _harness(
          composer: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return SessionComposer(
                enabled: true,
                busy: true,
                queued: List<QueuedTurn>.of(queued),
                onSubmit: (submission) => sent.add(submission.text),
                onSubmitAndInterrupt: (submission) =>
                    interrupted.add(submission.text),
                onQueue: (submission) => setState(
                  () => queued.add(
                    QueuedTurn(
                      id: 'q${queued.length}',
                      text: submission.text,
                      attachments: submission.attachments,
                    ),
                  ),
                ),
                onQueuedEdit: (id) {
                  final item = queued.where((q) => q.id == id).firstOrNull;
                  if (item != null) setState(() => queued.remove(item));
                  return item;
                },
                onQueuedSendNow: (id) =>
                    setState(() => queued.removeWhere((q) => q.id == id)),
                bar: _bar(),
              );
            },
          ),
        ),
      );

      // Typing is never taken away, and the button says what it will do.
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(findAccessibleAction(testL10n.composerQueueLabel), findsOneWidget);

      await tester.enterText(find.byKey(inputKey), 'follow up');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(queued.map((item) => item.text), <String>['follow up']);
      expect(sent, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('queued-turn-0')), findsOneWidget);

      // Editing brings the prompt back so it can be changed or dropped.
      await tester.tap(find.byKey(const ValueKey('queued-turn-0-edit')));
      await tester.pumpAndSettle();
      expect(queued, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'follow up',
      );

      // Ctrl+Enter goes past the running turn instead of waiting for it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(interrupted, <String>['follow up']);
      expect(queued, isEmpty);
      refresh(() {});
    },
  );

  testWidgets(
    'a queued prompt that stopped retrying shows why and stays actionable',
    tags: const <String>[
      'feature_test__conversation_turn_queue__widget',
      'ui_state__conversation_timeline__queued_error__widget',
    ],
    (tester) async {
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            busy: true,
            queued: const <QueuedTurn>[
              QueuedTurn(
                id: 'q0',
                text: 'follow up',
                attachments: <PendingAttachment>[],
                attempts: conversationDrainMaxAttempts,
                error: 'Exception: offline',
              ),
            ],
            onSubmit: (_) {},
            onQueue: (_) {},
            onQueuedEdit: (_) => null,
            onQueuedSendNow: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A prompt that has stopped trying must not read like one that is
      // simply waiting its turn, or nobody knows to act on it.
      final error = find.byKey(const ValueKey('queued-turn-0-error'));
      expect(error, findsOneWidget);
      expect(tester.widget<TRText>(error).color, TRTextColor.danger);
      expect(find.textContaining('offline'), findsOneWidget);

      final queuedCard = find.byKey(const ValueKey('queued-turn-0'));
      final queueIcon = find.descendant(
        of: queuedCard,
        matching: find.byIcon(TinestIcons.queue),
      );
      final prompt = find.descendant(
        of: queuedCard,
        matching: find.text('follow up'),
      );
      expect(
        tester.getRect(queueIcon).center.dy,
        closeTo(tester.getRect(prompt).center.dy, 0.5),
      );

      // Both ways out stay open: the prompt is never stranded beyond reach.
      expect(
        tester
            .widget<TRIconButton>(
              find.byKey(const ValueKey('queued-turn-0-edit')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TRIconButton>(
              find.byKey(const ValueKey('queued-turn-0-send')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'a failed send returns the prompt to the input',
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'ui_transition__conversation_timeline__retry_send__widget',
    ],
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) async {
              if (fail) throw Exception('offline');
            },
            bar: _bar(),
          ),
        ),
      );

      await tester.enterText(find.byKey(inputKey), 'keep me');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep me',
      );
      expect(
        find.byKey(const ValueKey('session-composer-attachment-error')),
        findsOneWidget,
      );

      fail = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'the card carries the focus of everything it frames',
    tags: const <String>['feature_test__session_lifecycle__widget'],
    (tester) async {
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool ringed() => tester.widget<TRCard>(find.byType(TRCard)).focused;
      Color inputBorder() => tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byKey(inputKey),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .map((container) => container.foregroundDecoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.border!.top.color)
          .first;

      expect(ringed(), isFalse);

      await tester.tap(find.byKey(inputKey));
      await tester.pumpAndSettle();
      expect(ringed(), isTrue);
      expect(
        inputBorder(),
        Colors.transparent,
        reason: 'the card rings the group, so the field must not ring itself',
      );

      // Tabbing on to an action inside the card keeps the group ringed: the
      // prompt and its controls are one control to the reader.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringed(), isTrue);

      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(ringed(), isFalse);
    },
  );

  testWidgets(
    'model layer keyboard focus does not paint the composer ring',
    tags: const <String>['feature_test__session_lifecycle__widget'],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composerCard = find.ancestor(
        of: find.byKey(inputKey),
        matching: find.byType(TRCard),
      );
      expect(composerCard, findsOneWidget);
      final focusColor = Theme.of(tester.element(composerCard))
          .extension<TinyrackThemeData>()!
          .focus;
      List<BorderSide> paintedComposerFocusBorders() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: composerCard,
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.border?.top)
          .nonNulls
          .where((side) => side.color == focusColor)
          .toList();

      final model = find.byKey(
        const ValueKey<String>('session-composer-model'),
      );
      await tester.tap(model);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(find.byType(TRDrawer), findsNothing);
      expect(find.textContaining('openai/gpt-5.6-sol'), findsOneWidget);
      expect(
        paintedComposerFocusBorders(),
        isEmpty,
        reason: 'overlay keyboard focus must not paint the composer group ring',
      );
      expect(
        tester.widget<TRCard>(composerCard).focused,
        isFalse,
        reason: 'the layer FocusScope is outside the composer focus subtree',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      final primaryContext = tester.binding.focusManager.primaryFocus?.context;
      expect(primaryContext, isNotNull);
      final primaryFocus = find.byElementPredicate(
        (element) => identical(element, primaryContext),
      );
      expect(
        find.ancestor(of: primaryFocus, matching: model),
        findsOneWidget,
        reason: 'closing the layer restores focus to its Select trigger',
      );
      expect(tester.widget<TRCard>(composerCard).focused, isTrue);
    },
  );

  testWidgets(
    'the composer swaps the labelled settings row for one settings sheet',
    tags: const <String>['feature_test__session_lifecycle__widget'],
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      const chips = <String>[
        'session-composer-agent',
        'session-composer-model',
        'session-composer-permission',
      ];
      const overflowKey = ValueKey<String>('session-composer-overflow');
      const settingsKey = ValueKey<String>('session-composer-settings');

      Future<void> pumpAt(double width, {double? composerWidth}) async {
        tester.view.physicalSize = Size(width, 800);
        final composer = SessionComposer(
          key: ValueKey<String>('$width-$composerWidth'),
          enabled: true,
          contextTokens: 100000,
          contextWindow: 200000,
          onSubmit: (_) {},
          bar: _bar(),
        );
        await tester.pumpWidget(
          _harness(
            composer: composerWidth == null
                ? composer
                : SizedBox(width: composerWidth, child: composer),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Exactly at the application density boundary, turn settings stay as
      // individual controls.
      await pumpAt(600);
      expect(tester.takeException(), isNull);
      for (final chip in chips) {
        expect(find.byKey(ValueKey<String>(chip)), findsOneWidget);
      }
      expect(find.byKey(overflowKey), findsNothing);
      expect(find.byKey(settingsKey), findsNothing);
      final standardSelects = tester
          .widgetList<TRSelect<dynamic>>(
            find.byWidgetPredicate((widget) => widget is TRSelect<dynamic>),
          )
          .toList(growable: false);
      expect(standardSelects, hasLength(3));
      for (final select in standardSelects) {
        expect(select.appearance, TRFieldAppearance.ghost);
        expect(select.uiSize, TRUiSize.sm);
      }
      expect(
        find.byKey(const ValueKey<String>('session-composer-mode')),
        findsNothing,
      );
      // Each turn setting is as wide as its own label, never a share of the
      // leftover row.
      final chipWidths = <String, double>{
        for (final chip in chips)
          chip: tester.getSize(find.byKey(ValueKey<String>(chip))).width,
      };
      for (final entry in chipWidths.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(TRMeasurements.measureMd),
          reason: '${entry.key} stops at the control cap',
        );
      }
      expect(
        chipWidths.values.toSet(),
        hasLength(chipWidths.length),
        reason: 'controls with different labels do not share one width',
      );
      expect(
        tester
            .getTopRight(
              find.byKey(const ValueKey<String>('session-composer-permission')),
            )
            .dx,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('session-composer-send')))
              .dx,
        ),
        reason: 'the settings row leaves the leftover space empty',
      );

      // Local composer width does not override the application density.
      await pumpAt(600, composerWidth: 500);
      expect(tester.takeException(), isNull);
      for (final chip in chips) {
        expect(find.byKey(ValueKey<String>(chip)), findsOneWidget);
      }
      expect(find.byKey(settingsKey), findsNothing);

      // One logical pixel below the density boundary the settings are
      // represented by one ghost action.
      await pumpAt(599);
      expect(tester.takeException(), isNull);
      for (final chip in chips) {
        expect(find.byKey(ValueKey<String>(chip)), findsNothing);
      }
      expect(find.byKey(overflowKey), findsNothing);
      expect(find.byKey(settingsKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(settingsKey)).height,
        TRControlMetrics.heightOf(TRUiSize.xl),
      );
      expect(
        find.byKey(const ValueKey<String>('session-composer-context-meter')),
        findsOneWidget,
      );
      // Prompt actions and context usage stay reachable in compact mode.
      expect(
        find.byKey(const ValueKey('session-composer-attach')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('session-composer-send')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'compact settings use one comfortable solid Select treatment',
    tags: const <String>['feature_test__session_lifecycle__widget'],
    (tester) async {
      const surfaceSize = Size(390, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = surfaceSize;
      await tester.pumpWidget(
        _harness(
          api: FakeTinestApi(
            agentDefinitions: _compactAgentDefinitions,
            models: const <String, List<ProviderModelDto>>{
              'openai': <ProviderModelDto>[_compactSettingsModel],
            },
          ),
          composer: const _CompactSettingsHost(),
        ),
      );
      await tester.pumpAndSettle();

      for (final key in <String>[
        'session-composer-settings',
        'session-composer-attach',
        'session-composer-send',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))).height,
          TRControlMetrics.heightOf(TRUiSize.xl),
        );
      }
      expect(
        tester.widget<TRCard>(find.byType(TRCard).first).padding,
        TRCardPadding.md,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('session-composer-settings')),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(
        const ValueKey<String>('session-composer-settings-sheet'),
      );
      expect(
        tester.getSize(sheet).height,
        lessThanOrEqualTo(surfaceSize.height * 0.7),
      );
      expect(tester.getBottomLeft(sheet).dy, surfaceSize.height);

      final selectWidths = <double>[];
      for (final setting in <String>[
        'agent',
        'model',
        'control-reasoning_effort',
        'permission',
      ]) {
        final row = find.byKey(
          ValueKey<String>('session-composer-settings-$setting'),
        );
        final select = find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) => widget is TRSelect<dynamic>,
          ),
        );
        expect(select, findsOneWidget, reason: setting);
        final widget = tester.widget<TRSelect<dynamic>>(select);
        expect(widget.appearance, TRFieldAppearance.solid, reason: setting);
        expect(widget.uiSize, isNull, reason: setting);
        expect(
          tester.getSize(select).height,
          TRControlMetrics.heightOf(TRUiSize.xl),
          reason: '$setting inherits comfortable density',
        );
        selectWidths.add(tester.getSize(select).width);
      }
      for (final width in selectWidths.skip(1)) {
        expect(width, selectWidths.first);
      }
      expect(
        selectWidths.first,
        greaterThan(TRMeasurements.measureMd),
        reason: 'sheet controls still stretch to their settings row',
      );

      final handle = find.byKey(
        const ValueKey<String>('tr-drawer-drag-handle'),
      );
      final startingHandleRect = tester.getRect(handle);
      await tester.timedDrag(handle, const Offset(0, -120), TRMotion.slow);
      await tester.pumpAndSettle();
      expect(tester.getRect(handle), startingHandleRect);

      final agentSelect = find.byKey(
        const ValueKey<String>('session-composer-settings-agent-select'),
      );
      final startingAgentTop = tester.getRect(agentSelect).top;
      await tester.timedDrag(agentSelect, const Offset(0, -80), TRMotion.slow);
      await tester.pumpAndSettle();
      expect(tester.getRect(handle), startingHandleRect);
      expect(tester.getRect(agentSelect).top, lessThan(startingAgentTop));
      await tester.timedDragFrom(
        const Offset(195, 600),
        const Offset(0, 80),
        TRMotion.slow,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(handle), startingHandleRect);

      final headerGesture = await tester.startGesture(
        tester.getCenter(find.text(testL10n.composerMoreSettings)),
      );
      await headerGesture.moveBy(const Offset(0, 20));
      await headerGesture.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(tester.getRect(handle).top, greaterThan(startingHandleRect.top));
      await headerGesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(handle), startingHandleRect);

      for (final setting in <String>['agent', 'model', 'permission']) {
        final select = find.byKey(
          ValueKey<String>('session-composer-settings-$setting-select'),
        );
        await tester.ensureVisible(select);
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
        expect(find.byType(TRDrawer), findsNWidgets(2), reason: setting);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TRDrawer), findsOneWidget, reason: setting);
      }

      await tester.timedDrag(handle, const Offset(0, 300), TRMotion.fast);
      await tester.pumpAndSettle();
      expect(find.byType(TRDrawer), findsNothing);
    },
  );

  testWidgets(
    'compact settings keep the parent sheet while every value uses a child',
    tags: const <String>['feature_test__session_lifecycle__widget'],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final hostKey = GlobalKey<_CompactSettingsHostState>();
      final api = FakeTinestApi(
        agentDefinitions: _compactAgentDefinitions,
        models: const <String, List<ProviderModelDto>>{
          'openai': <ProviderModelDto>[_compactSettingsModel],
        },
      );
      await tester.pumpWidget(
        _harness(
          api: api,
          composer: TRUiDensityScope(
            density: TRUiDensity.comfortable,
            child: _CompactSettingsHost(key: hostKey),
          ),
          mediaPadding: const EdgeInsets.only(top: 24, bottom: 34),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('session-composer-settings')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('session-composer-settings-sheet')),
        findsOneWidget,
      );
      final settingsDrawer = find.byType(TRDrawer);
      final settingsSafeArea = find.descendant(
        of: settingsDrawer,
        matching: find.byType(SafeArea),
      );
      final settingsSafeContent = find.descendant(
        of: settingsSafeArea,
        matching: find.byType(Padding),
      );
      expect(tester.getRect(settingsDrawer).bottom, 760);
      expect(tester.getRect(settingsSafeContent.at(1)).bottom, 726);
      final settingsHandle = find.byKey(
        const ValueKey<String>('tr-drawer-drag-handle'),
      );
      expect(
        tester.getRect(settingsHandle).top - tester.getRect(settingsDrawer).top,
        TRSpacing.medium + TRControlMetrics.borderWidth,
      );
      for (final setting in <String>[
        'agent',
        'model',
        'control-reasoning_effort',
        'control-fast_mode',
        'control-thinking_budget',
        'permission',
      ]) {
        expect(
          find.byKey(ValueKey<String>('session-composer-settings-$setting')),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.byKey(
          const ValueKey<String>('session-composer-settings-model-select'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRDrawer), findsOneWidget);
      expect(find.byType(TRDialog), findsNothing);
      final modelDrawer = find.byType(TRDrawer);
      final modelHandle = find.byKey(
        const ValueKey<String>('tr-drawer-drag-handle'),
      );
      expect(
        tester.getRect(modelHandle).top - tester.getRect(modelDrawer).top,
        TRSpacing.medium + TRControlMetrics.borderWidth,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TRDrawer), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('session-composer-settings-agent-select'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('session-composer-agent-planner')),
      );
      await tester.pumpAndSettle();
      expect(hostKey.currentState!.agentId, 'planner');
      expect(find.byType(TRDrawer), findsOneWidget);
      expect(find.text('Planner'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'session-composer-settings-control-reasoning_effort-select',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'session-composer-control-reasoning_effort-high',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        hostKey.currentState!.controls['reasoning_effort'],
        const ModelControlValueDto.stringValue(value: 'high'),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('session-composer-settings-control-fast_mode'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        hostKey.currentState!.controls['fast_mode'],
        const ModelControlValueDto.boolValue(value: true),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'session-composer-settings-control-thinking_budget',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>(
            'session-composer-control-thinking_budget-integer',
          ),
        ),
        '7',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'session-composer-control-thinking_budget-save',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        hostKey.currentState!.controls['thinking_budget'],
        const ModelControlValueDto.intValue(value: 7),
      );

      final permissionSetting = find.byKey(
        const ValueKey<String>('session-composer-settings-permission'),
      );
      await tester.ensureVisible(permissionSetting);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('session-composer-settings-permission-select'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('permission-option-readOnly')),
      );
      await tester.pumpAndSettle();
      expect(hostKey.currentState!.permissionMode, PermissionMode.readOnly);

      expect(
        find.byKey(const ValueKey<String>('session-composer-settings-mode')),
        findsNothing,
      );
      expect(find.byType(TRDrawer), findsOneWidget);
    },
  );

  testWidgets(
    'compact settings explain the locked agent state without closing',
    tags: const <String>['feature_test__session_lifecycle__widget'],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _harness(
          api: FakeTinestApi(agentDefinitions: _compactAgentDefinitions),
          composer: const TRUiDensityScope(
            density: TRUiDensity.comfortable,
            child: _CompactSettingsHost(agentEnabled: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('session-composer-settings')),
      );
      await tester.pumpAndSettle();

      final agentRow = find.byKey(
        const ValueKey<String>('session-composer-settings-agent'),
      );
      expect(
        find.descendant(of: agentRow, matching: find.byIcon(TinestIcons.lock)),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<TRText>(
              find.descendant(of: agentRow, matching: find.byType(TRText)),
            )
            .first
            .color,
        TRTextColor.muted,
      );
      final blockedAgent = find.descendant(
        of: agentRow,
        matching: find.byType(BlockedControl),
      );
      expect(
        tester.getSemantics(blockedAgent).hint,
        testL10n.composerAgentLocked,
      );
      final container = ProviderScope.containerOf(tester.element(agentRow));
      final toasts = container.read(appToastControllerProvider);

      await tester.tap(blockedAgent);
      await tester.pumpAndSettle();

      expect(find.byType(TRDrawer), findsOneWidget);
      expect(toasts.toasts, hasLength(1));
      expect(toasts.toasts.single.variant, TRStatusVariant.info);
      expect(
        (toasts.toasts.single.title as TRText).data,
        testL10n.composerAgentLocked,
      );

      Focus.of(
        tester.element(
          find
              .descendant(of: blockedAgent, matching: find.byType(MouseRegion))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(toasts.toasts, hasLength(1));
      expect(find.byType(TRDrawer), findsOneWidget);
    },
  );

  testWidgets(
    'compact settings explain the missing provider for model selection',
    tags: const <String>[
      'feature_test__session_lifecycle__widget',
      'feature_test__app_toast__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _harness(
          api: FakeTinestApi(connections: const <ProviderConnectionDto>[]),
          composer: const TRUiDensityScope(
            density: TRUiDensity.comfortable,
            child: _CompactSettingsHost(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('session-composer-settings')),
      );
      await tester.pumpAndSettle();

      final modelRow = find.byKey(
        const ValueKey<String>('session-composer-settings-model'),
      );
      expect(
        find.descendant(of: modelRow, matching: find.byIcon(TinestIcons.lock)),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<TRText>(
              find.descendant(of: modelRow, matching: find.byType(TRText)),
            )
            .first
            .color,
        TRTextColor.muted,
      );
      final blockedModel = find.descendant(
        of: modelRow,
        matching: find.byType(BlockedControl),
      );
      expect(
        tester.getSemantics(blockedModel).hint,
        testL10n.composerConnectProviderFirst,
      );
      final container = ProviderScope.containerOf(tester.element(modelRow));
      final toasts = container.read(appToastControllerProvider);

      await tester.tap(blockedModel);
      await tester.pumpAndSettle();

      expect(find.byType(TRDrawer), findsOneWidget);
      expect(find.byType(AsyncModelSelect), findsOneWidget);
      expect(toasts.toasts, hasLength(1));
      expect(toasts.toasts.single.variant, TRStatusVariant.info);
      expect(
        (toasts.toasts.single.title as TRText).data,
        testL10n.composerConnectProviderFirst,
      );

      Focus.of(
        tester.element(
          find
              .descendant(of: blockedModel, matching: find.byType(MouseRegion))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(toasts.toasts, hasLength(1));
      expect(find.byType(TRDrawer), findsOneWidget);
    },
  );

  testWidgets(
    'wide model chip explains the missing provider without opening a picker',
    tags: const <String>[
      'feature_test__session_lifecycle__widget',
      'feature_test__app_toast__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _harness(
          api: FakeTinestApi(connections: const <ProviderConnectionDto>[]),
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final modelChip = find.byKey(
        const ValueKey<String>('session-composer-model'),
      );
      expect(
        tester
            .widget<TRSelect<ModelPickerOption>>(
              find.descendant(
                of: modelChip,
                matching: find.byType(TRSelect<ModelPickerOption>),
              ),
            )
            .enabled,
        isFalse,
        reason: 'the blocked chip keeps the design-system disabled styling',
      );
      expect(
        tester.getSemantics(modelChip).hint,
        testL10n.composerConnectProviderFirst,
      );
      final container = ProviderScope.containerOf(tester.element(modelChip));
      final toasts = container.read(appToastControllerProvider);

      await tester.tap(modelChip);
      await tester.pumpAndSettle();

      expect(find.byType(AsyncModelSelect), findsOneWidget);
      expect(toasts.toasts, hasLength(1));
      expect(toasts.toasts.single.variant, TRStatusVariant.info);
      expect(
        (toasts.toasts.single.title as TRText).data,
        testL10n.composerConnectProviderFirst,
      );
    },
  );

  testWidgets(
    'the composer names no shortcut it does not implement',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );

      expect(find.textContaining('Ctrl+L'), findsNothing);
    },
  );

  testWidgets(
    'the context meter appears only once a window is known',
    tags: const <String>['feature_test__tool_context_budget__widget'],
    (tester) async {
      const meterKey = ValueKey<String>('session-composer-context-meter');

      // A provider that never advertised a window would make any percentage a
      // fiction, so nothing is drawn at all.
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            contextTokens: 4000,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(meterKey), findsNothing);

      for (final expected in <(int, TRStatusVariant)>[
        (0, TRStatusVariant.neutral),
        (140000, TRStatusVariant.warning),
        (180000, TRStatusVariant.warning),
        (200000, TRStatusVariant.danger),
      ]) {
        await tester.pumpWidget(
          _harness(
            composer: SessionComposer(
              enabled: true,
              contextTokens: expected.$1,
              contextWindow: 200000,
              onSubmit: (_) {},
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final meter = tester.widget<TRRadialMeter>(find.byKey(meterKey));
        expect(meter.variant, expected.$2, reason: '${expected.$1} tokens');
        expect(meter.max, 100);
        expect(meter.value, expected.$1 / 2000);
        expect(meter.uiSize, isNull);
      }
    },
  );

  testWidgets(
    'hover opens context details and lazily loads current provider quota',
    tags: const <String>[
      'feature_test__tool_context_budget__widget',
      'feature_test__provider_usage__widget',
    ],
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            contextTokens: 150000,
            contextWindow: 200000,
            totalCostUsd: 1.25,
            providerConnectionId: 'openai',
            onLoadProviderUsage: () async {
              loads += 1;
              return <ProviderUsageDto>[
                ProviderUsageDto(
                  connectionId: 'openai',
                  status: ProviderUsageStatus.available,
                  fetchedAt: DateTime.utc(2026),
                  provider: 'OpenAI',
                  plan: 'plus',
                  windows: const <ProviderUsageWindowDto>[
                    ProviderUsageWindowDto(
                      kind: ProviderUsageWindowKind.session,
                      usedPercent: 40,
                    ),
                  ],
                ),
              ];
            },
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(pointer.removePointer);
      await pointer.addPointer(location: Offset.zero);
      await pointer.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey<String>('session-composer-context-meter')),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(loads, 1);
      expect(find.text('75% 사용'), findsOneWidget);
      expect(find.text('150K / 200K 토큰'), findsOneWidget);
      expect(find.text(r'세션 비용 $1.25'), findsOneWidget);
      expect(find.text('OpenAI · plus'), findsOneWidget);
      expect(find.text('세션 한도'), findsOneWidget);
      expect(loads, 1);
    },
  );

  testWidgets(
    'keyboard focus opens context details and loads quota once',
    tags: const <String>[
      'feature_test__tool_context_budget__widget',
      'feature_test__provider_usage__widget',
    ],
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            contextTokens: 150000,
            contextWindow: 200000,
            providerConnectionId: 'openai',
            onLoadProviderUsage: () async {
              loads += 1;
              return const <ProviderUsageDto>[];
            },
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );

      expect(find.text('컨텍스트 사용량'), findsNothing);
      final trigger = find.byKey(
        const ValueKey<String>('session-composer-context-trigger'),
      );
      final triggerFocus =
          tester
                .widgetList<Focus>(
                  find.descendant(of: trigger, matching: find.byType(Focus)),
                )
                .singleWhere(
                  (focus) =>
                      focus.focusNode?.debugLabel ==
                      'session-composer-context-trigger',
                )
                .focusNode!
            ..requestFocus();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(triggerFocus.hasFocus, isTrue);
      expect(loads, 1);
      expect(find.text('컨텍스트 사용량'), findsOneWidget);
    },
  );

  testWidgets(
    'a composer shows one keyboard ring and no pointer ring',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      TRFocusSource.instance.debugReset();
      addTearDown(TRFocusSource.instance.debugReset);
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (_) {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(inputKey));
      await tester.pumpAndSettle();

      final composerCard = find.ancestor(
        of: find.byKey(inputKey),
        matching: find.byType(TRCard),
      );
      expect(composerCard, findsOneWidget);
      final focus = Theme.of(tester.element(composerCard))
          .extension<TinyrackThemeData>()!
          .focus;
      List<BorderSide> rings() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: composerCard,
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.border?.top)
          .nonNulls
          .where((side) => side.color == focus)
          .toList();

      expect(rings(), isEmpty);

      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      TRFocusSource.instance.debugSetKeyboardModality(true);
      await tester.pumpAndSettle();
      expect(rings(), hasLength(1));
      expect(rings().single.width, TRControlMetrics.focusWidth);
    },
  );

  testWidgets(
    'a file mention completes into the prompt instead of sending',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), 'read @li');
      await tester.pumpAndSettle();
      expect(find.text('lib/app.dart'), findsOneWidget);

      // Down then Enter picks the second row and splices it; nothing is sent.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(submitted, isEmpty);
      expect(
        tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
        'read @lib/composer.dart ',
      );

      // With the list closed, Enter sends the completed prompt.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, <String>['read @lib/composer.dart']);
    },
  );

  testWidgets(
    'Enter waits for a mention whose list has not arrived yet',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
          // The search is debounced and asynchronous, so the list is not on
          // screen on the frame the user presses Enter.
          suppressList: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), 'read @READ');
      await tester.pumpAndSettle();
      expect(find.text('README.md'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // The half-typed mention is neither sent nor lost.
      expect(submitted, isEmpty);
      expect(
        tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
        'read @READ',
      );

      // A finished mention sends as usual.
      await tester.enterText(find.byKey(inputKey), 'read @README.md ');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, <String>['read @README.md']);
    },
  );

  testWidgets(
    'Escape closes the mention list and returns Enter to sending',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), 'read @li');
      await tester.pumpAndSettle();
      expect(find.text('lib/app.dart'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('lib/app.dart'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, <String>['read @li']);
    },
  );

  testWidgets(
    'an open list takes plain Tab and leaves modified Tab alone',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      await tester.pumpWidget(_completionHarness(onSubmit: (_) {}));
      await tester.pumpAndSettle();

      Future<void> shiftTab() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
      }

      // Closed, Shift+Tab is left to the host/plugin layer.
      await tester.enterText(find.byKey(inputKey), 'plain');
      await tester.pumpAndSettle();
      await shiftTab();
      expect(
        tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
        'plain',
      );

      // A held modifier is not interpreted by the completion list.
      await tester.enterText(find.byKey(inputKey), '@li');
      await tester.pumpAndSettle();
      expect(find.text('lib/app.dart'), findsOneWidget);
      await shiftTab();
      expect(
        tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
        '@li',
      );

      // The host focus traversal owns modified Tab. Refocus the input before
      // proving that an unmodified Tab belongs to the still-open list.
      await tester.tap(find.byKey(inputKey));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
        '@lib/app.dart ',
      );
    },
  );

  testWidgets(
    'Shift+Enter opens a line even with the list open',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), 'read @li');
      await tester.pumpAndSettle();
      expect(find.text('lib/app.dart'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // Neither committed nor sent: the newline belongs to the field.
      expect(submitted, isEmpty);
      expect(
        tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
        'read @li',
      );
    },
  );

  testWidgets(
    'a client command runs in the app and never starts a turn',
    tags: const <String>['feature_test__composer_slash_command__widget'],
    (tester) async {
      final submitted = <String>[];
      final ran = <ClientCommandAction>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
          onClientCommand: (invocation) async {
            ran.add(invocation.command.action!);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), '/cle');
      await tester.pumpAndSettle();
      expect(find.text('clear'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(ran, <ClientCommandAction>[ClientCommandAction.clear]);
      expect(submitted, isEmpty);
    },
  );

  testWidgets(
    'a client command with attachments is refused rather than dropped',
    tags: const <String>['feature_test__composer_slash_command__widget'],
    (tester) async {
      final ran = <ClientCommandAction>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (_) {},
          attachmentInput: const _OneFileAttachmentInput(),
          onClientCommand: (invocation) async {
            ran.add(invocation.command.action!);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('session-composer-attach')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(inputKey), '/clear');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(ran, isEmpty);
      expect(
        find.byKey(const ValueKey('session-composer-attachment-error')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a command with no handler submits as ordinary text',
    tags: const <String>['feature_test__composer_slash_command__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), '/clear');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(submitted, <String>['/clear']);
    },
  );

  testWidgets(
    'a skill command is expanded into the prompt that is sent',
    tags: const <String>[
      'feature_test__composer_slash_command__widget',
      'feature_test__skill_invocation__widget',
    ],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(inputKey), '/commit split it');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(submitted, <String>['Use the "commit" skill.\n\nsplit it']);
    },
  );

  testWidgets(
    'an open list does not send on the Enter that ends a composition',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (submission) => submitted.add(submission.text),
        ),
      );
      await tester.pumpAndSettle();

      // A live Korean composition spanning the token: no list, and the Enter
      // that commits the composition must not send either.
      final field = tester.widget<TRTextField>(find.byKey(inputKey));
      field.controller!.value = const TextEditingValue(
        text: '@한',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(submitted, isEmpty);
    },
  );

  testWidgets(
    'file mention keyboard selection stays inside the scroll viewport',
    tags: const <String>['feature_test__composer_file_mention__widget'],
    (tester) async {
      await tester.pumpWidget(
        _completionHarness(
          onSubmit: (_) {},
          files: const <String>[
            'lib/01.dart',
            'lib/02.dart',
            'lib/03.dart',
            'lib/04.dart',
            'lib/05.dart',
            'lib/06.dart',
            'lib/07.dart',
            'lib/08.dart',
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(inputKey), '@');
      await tester.pumpAndSettle();

      final scrollArea = find.descendant(
        of: find.byType(TRInlineSuggestions<String>),
        matching: find.byType(TRScrollArea),
      );
      bool isVisible(String label) {
        final viewport = tester.getRect(scrollArea);
        final row = tester.getRect(find.text(label));
        return row.top >= viewport.top && row.bottom <= viewport.bottom;
      }

      expect(isVisible('lib/08.dart'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(isVisible('lib/08.dart'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(isVisible('lib/01.dart'), isTrue);
    },
  );

  testWidgets(
    'slash command keyboard selection stays inside the scroll viewport',
    tags: const <String>['feature_test__composer_slash_command__widget'],
    (tester) async {
      await tester.pumpWidget(_completionHarness(onSubmit: (_) {}));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(inputKey), '/');
      await tester.pumpAndSettle();

      final scrollArea = find.descendant(
        of: find.byType(TRInlineSuggestions<String>),
        matching: find.byType(TRScrollArea),
      );
      bool isVisible(String label) {
        final viewport = tester.getRect(scrollArea);
        final row = tester.getRect(find.text(label));
        return row.top >= viewport.top && row.bottom <= viewport.bottom;
      }

      expect(isVisible('skills'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(isVisible('skills'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(isVisible('new'), isTrue);
    },
  );

  testWidgets(
    'a running turn is stopped from the composer, and typing still queues',
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'ui_transition__conversation_timeline__cancel_turn__widget',
    ],
    (tester) async {
      var stops = 0;
      final queued = <String>[];
      final submitted = <String>[];
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            busy: true,
            onSubmit: (submission) => submitted.add(submission.text),
            onQueue: (submission) => queued.add(submission.text),
            onStop: () => stops += 1,
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An empty composer over a running turn offers the one thing worth
      // doing: stopping it.
      expect(find.byKey(stopKey), findsOneWidget);
      expect(find.byKey(sendKey), findsNothing);
      await tester.tap(find.byKey(stopKey));
      await tester.pumpAndSettle();
      expect(stops, 1);
      expect(submitted, isEmpty);

      // Typing ahead still queues, and reads as sending rather than queueing
      // so the primary action never changes meaning mid-sentence.
      await tester.enterText(find.byKey(inputKey), 'follow up');
      await tester.pumpAndSettle();
      expect(find.byKey(stopKey), findsNothing);
      final send = find.byKey(sendKey);
      expect(send, findsOneWidget);
      expect(
        find.descendant(of: send, matching: find.byIcon(TinestIcons.send)),
        findsOneWidget,
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(queued, <String>['follow up']);
      expect(stops, 1);
    },
  );

  testWidgets(
    'a composer with no running turn keeps sending',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _harness(
          composer: SessionComposer(
            enabled: true,
            onSubmit: (submission) => submitted.add(submission.text),
            onStop: () {},
            bar: _bar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(stopKey), findsNothing);
      await tester.enterText(find.byKey(inputKey), 'hello');
      await tester.tap(find.byKey(sendKey));
      await tester.pumpAndSettle();
      expect(submitted, <String>['hello']);
    },
  );

  group('every send path leaves the caret in the prompt', () {
    // The trailing action grabs focus on pointer-down, so a mouse send parks
    // the caret on a button that `busy` is about to replace with Stop, taking
    // the focused node down with it. Asserted through the primary focus rather
    // than through the card's ring, so a passing test means the next keystroke
    // actually reaches the field.
    void expectPromptFocused(WidgetTester tester, {required String reason}) {
      final primaryContext = tester.binding.focusManager.primaryFocus?.context;
      expect(primaryContext, isNotNull, reason: reason);
      expect(
        find.ancestor(
          of: find.byElementPredicate(
            (element) => identical(element, primaryContext),
          ),
          matching: find.byKey(inputKey),
        ),
        findsOneWidget,
        reason: reason,
      );
    }

    testWidgets(
      'sending with the button returns focus to the input',
      tags: const <String>['feature_test__turn_execution__widget'],
      (tester) async {
        final submitted = <String>[];
        await tester.pumpWidget(
          _harness(
            composer: SessionComposer(
              enabled: true,
              onSubmit: (submission) => submitted.add(submission.text),
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), 'hello');
        await tester.tap(find.byKey(sendKey));
        await tester.pumpAndSettle();

        expect(submitted, <String>['hello']);
        expectPromptFocused(tester, reason: 'button send');
      },
    );

    testWidgets(
      'focus returns before the send completes, not after',
      tags: const <String>['feature_test__turn_execution__widget'],
      (tester) async {
        // The upload inside a send can take seconds. A field that only wakes
        // up once the daemon answers is the bug, so the assertion runs while
        // the submission is still in flight.
        final gate = Completer<void>();
        await tester.pumpWidget(
          _harness(
            composer: SessionComposer(
              enabled: true,
              onSubmit: (_) => gate.future,
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), 'slow');
        await tester.tap(find.byKey(sendKey));
        await tester.pump();

        expectPromptFocused(tester, reason: 'send still in flight');

        gate.complete();
        await tester.pumpAndSettle();
        expectPromptFocused(tester, reason: 'send settled');
      },
    );

    testWidgets(
      'queueing over a running turn keeps focus',
      tags: const <String>['feature_test__turn_execution__widget'],
      (tester) async {
        final queued = <String>[];
        await tester.pumpWidget(
          _harness(
            composer: SessionComposer(
              enabled: true,
              busy: true,
              onSubmit: (_) {},
              onQueue: (submission) => queued.add(submission.text),
              onStop: () {},
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), 'follow up');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(sendKey));
        await tester.pumpAndSettle();

        expect(queued, <String>['follow up']);
        expectPromptFocused(tester, reason: 'queue branch');
      },
    );

    testWidgets(
      'running a client command keeps focus',
      tags: const <String>['feature_test__turn_execution__widget'],
      (tester) async {
        final invoked = <String>[];
        await tester.pumpWidget(
          _harness(
            composer: SessionComposer(
              enabled: true,
              onSubmit: (_) {},
              commands: mergeComposerCommands(
                client: clientComposerCommands,
                agent: const <AgentCommandDto>[],
                skills: const <SkillSummaryDto>[],
              ),
              onClientCommand: (invocation) async {
                invoked.add(invocation.command.id);
                return true;
              },
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), '/clear');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(sendKey));
        await tester.pumpAndSettle();

        expect(invoked, <String>['client:clear']);
        expectPromptFocused(tester, reason: 'client command');
      },
    );

    testWidgets(
      'a touch platform keeps its keyboard open after sending',
      tags: const <String>['feature_test__turn_execution__widget'],
      (tester) async {
        // Android and iOS never submit on Enter, so the button is their only
        // send path: letting the tap close the keyboard would end every
        // message with a dismissed keyboard.
        final submitted = <String>[];
        await tester.pumpWidget(
          _harness(
            platform: TargetPlatform.android,
            composer: SessionComposer(
              enabled: true,
              onSubmit: (submission) => submitted.add(submission.text),
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), 'hello');
        await tester.tap(find.byKey(sendKey));
        await tester.pumpAndSettle();

        expect(submitted, <String>['hello']);
        expectPromptFocused(tester, reason: 'android button send');
      },
    );

    testWidgets(
      'sending with Enter still keeps focus',
      tags: const <String>['feature_test__turn_execution__widget'],
      (tester) async {
        // Enter never lost focus. Pinned so the button repair cannot be
        // written in a way that takes it away from the keyboard path.
        final submitted = <String>[];
        await tester.pumpWidget(
          _harness(
            composer: SessionComposer(
              enabled: true,
              onSubmit: (submission) => submitted.add(submission.text),
              bar: _bar(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(inputKey), 'hello');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(submitted, <String>['hello']);
        expectPromptFocused(tester, reason: 'enter send');
      },
    );
  });
}

const _compactAgentDefinitions = <AgentDefinitionDto>[
  AgentDefinitionDto(
    version: 5,
    id: 'tinest',
    name: 'Tinest',
    description: 'Codes',
    mode: AgentMode.primary,
    model: AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'tinest.standard/driver',
    extensionIds: <String>[],
    toolIds: <String>[],
    pluginSettings: <String, Map<String, dynamic>>{},
    callableAgentIds: <String>[],
    prompt: 'Code.',
    contentHash: 'tinest-hash',
    sourcePath: '/agents/tinest.md',
    isBuiltIn: true,
  ),
  AgentDefinitionDto(
    version: 5,
    id: 'planner',
    name: 'Planner',
    description: 'Plans',
    mode: AgentMode.primary,
    model: AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'tinest.standard/driver',
    extensionIds: <String>[],
    toolIds: <String>[],
    pluginSettings: <String, Map<String, dynamic>>{},
    callableAgentIds: <String>[],
    prompt: 'Plan.',
    contentHash: 'planner-hash',
    sourcePath: '/agents/planner.md',
  ),
];

const _compactSettingsModel = ProviderModelDto(
  connectionId: 'openai',
  id: 'openai/gpt-settings',
  providerModelId: 'gpt-settings',
  label: 'GPT Settings',
  source: ProviderModelSource.bundled,
  capabilities: ModelCapabilitiesDto(
    streaming: CapabilitySupport.supported,
    toolCalling: CapabilitySupport.supported,
    controls: <ModelControlDescriptorDto>[
      ModelControlDescriptorDto(
        id: 'reasoning_effort',
        label: 'Reasoning effort',
        kind: ModelControlKind.choice,
        presentation: ModelControlPresentation.menuChip,
        choices: <ModelControlChoiceDto>[
          ModelControlChoiceDto(id: 'low', label: 'Low'),
          ModelControlChoiceDto(id: 'high', label: 'High'),
        ],
      ),
      ModelControlDescriptorDto(
        id: 'fast_mode',
        label: 'Fast',
        kind: ModelControlKind.toggle,
        presentation: ModelControlPresentation.selectableChip,
      ),
      ModelControlDescriptorDto(
        id: 'thinking_budget',
        label: 'Thinking budget',
        kind: ModelControlKind.integer,
        presentation: ModelControlPresentation.menuChip,
        minimum: 1,
        maximum: 9,
        step: 2,
      ),
    ],
  ),
);

class _CompactSettingsHost extends StatefulWidget {
  const new({this.agentEnabled = true, super.key});

  final bool agentEnabled;

  @override
  State<_CompactSettingsHost> createState() => _CompactSettingsHostState();
}

class _CompactSettingsHostState extends State<_CompactSettingsHost> {
  String agentId = 'tinest';
  PermissionMode? permissionMode;
  Map<String, ModelControlValueDto> controls = <String, ModelControlValueDto>{};

  @override
  Widget build(BuildContext context) => SessionComposer(
    enabled: true,
    onSubmit: (_) {},
    bar: SessionComposerBar(
      hostId: 'server',
      definitions: _compactAgentDefinitions,
      agentDefinitionId: agentId,
      selection: const ModelSelectionDto(modelId: 'openai/gpt-settings'),
      onAgentChanged: (value) => setState(() => agentId = value),
      onModelChanged: (_, nextControls) =>
          setState(() => controls = nextControls),
      modelControls: controls,
      onModelControlsChanged: (value) => setState(() => controls = value),
      permissionMode: permissionMode,
      onPermissionModeChanged: (value) =>
          setState(() => permissionMode = value),
      agentEnabled: widget.agentEnabled,
    ),
  );
}

Widget _harness({
  required Widget composer,
  TargetPlatform platform = TargetPlatform.linux,
  FakeTinestApi? api,
  EdgeInsets mediaPadding = EdgeInsets.zero,
}) => ProviderScope(
  overrides: [
    appServicesProvider.overrideWithValue(
      fakeAppServices(api ?? FakeTinestApi()),
    ),
  ],
  child: MaterialApp(
    theme: testLightTheme.copyWith(platform: platform),
    locale: testLocale,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(padding: mediaPadding, viewPadding: mediaPadding),
      child: TinestUiDensity(child: child!),
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: composer),
    ),
  ),
);

Widget _pageHarness({
  required Widget composer,
  required EdgeInsets viewInsets,
}) => ProviderScope(
  overrides: [
    appServicesProvider.overrideWithValue(fakeAppServices(FakeTinestApi())),
  ],
  child: MaterialApp(
    theme: testLightTheme.copyWith(platform: TargetPlatform.android),
    locale: testLocale,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
      child: TinestUiDensity(child: child!),
    ),
    home: TinestPageShell(
      body: Align(alignment: Alignment.bottomCenter, child: composer),
    ),
  ),
);

SessionComposerBar _bar() => SessionComposerBar(
  hostId: 'server',
  definitions: const <AgentDefinitionDto>[],
  agentDefinitionId: null,
  selection: null,
  onAgentChanged: (_) {},
  onModelChanged: (_, _) {},
);

/// A composer wired to a fixed catalog, so the tests exercise the composer
/// rather than the daemon-backed providers behind it.
Widget _completionHarness({
  required void Function(ComposerSubmission submission) onSubmit,
  Future<bool> Function(ComposerCommandInvocation invocation)? onClientCommand,
  AttachmentInputPort? attachmentInput,
  bool suppressList = false,
  List<String> files = _files,
}) => _harness(
  composer: _CompletionHost(
    onSubmit: onSubmit,
    onClientCommand: onClientCommand,
    attachmentInput: attachmentInput,
    suppressList: suppressList,
    files: files,
  ),
);

const List<String> _files = <String>[
  'lib/app.dart',
  'lib/composer.dart',
  'README.md',
];

/// Holds the active token the way the real completion scope does.
class _CompletionHost extends StatefulWidget {
  const new({
    required this.onSubmit,
    this.onClientCommand,
    this.attachmentInput,
    this.suppressList = false,
    this.files = _files,
  });

  final void Function(ComposerSubmission submission) onSubmit;
  final Future<bool> Function(ComposerCommandInvocation invocation)?
  onClientCommand;
  final AttachmentInputPort? attachmentInput;
  final bool suppressList;
  final List<String> files;

  @override
  State<_CompletionHost> createState() => _CompletionHostState();
}

class _CompletionHostState extends State<_CompletionHost> {
  ComposerTrigger? _trigger;

  late final List<ComposerCommand> _commands = mergeComposerCommands(
    client: clientComposerCommands,
    agent: const <AgentCommandDto>[],
    skills: const <SkillSummaryDto>[
      SkillSummaryDto(
        id: 'commit',
        name: 'commit',
        description: 'Writes atomic commits.',
        isImplicit: false,
      ),
    ],
  );

  ComposerSuggestionsState get _suggestions {
    final trigger = _trigger;
    // Stands in for the window before a debounced search has resolved, when
    // the token is typed but the list is not on screen yet.
    if (trigger == null || widget.suppressList) {
      return ComposerSuggestionsState.closed;
    }
    if (trigger.kind == ComposerTriggerKind.command) {
      return ComposerSuggestionsState(
        trigger: trigger,
        items: commandSuggestions(_commands, trigger.query),
      );
    }
    final matches = <FileMatchDto>[
      for (final path in widget.files)
        if (fuzzyMatch(path, trigger.query) != null)
          FileMatchDto(
            relativePath: path,
            absolutePath: '/worktree/$path',
            name: path.split('/').last,
            isDirectory: false,
          ),
    ];
    return ComposerSuggestionsState(
      trigger: trigger,
      items: fileSuggestions(
        rankFileMatches(matches, trigger.query),
        trigger.query,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SessionComposer(
    enabled: true,
    commands: _commands,
    suggestions: _suggestions,
    onCompletionQueryChanged: (trigger) => setState(() => _trigger = trigger),
    onClientCommand: widget.onClientCommand,
    attachmentInput: widget.attachmentInput,
    onSubmit: widget.onSubmit,
    bar: _bar(),
  );
}

/// Supplies exactly one attachment, so a command submission has something to
/// collide with.
final class _OneFileAttachmentInput implements AttachmentInputPort {
  const new();

  @override
  bool get supportsDrop => false;

  @override
  Future<List<PendingAttachment>> pickFiles() async => <PendingAttachment>[
    PendingAttachment.fromBytes(
      fileName: 'notes.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    ),
  ];

  @override
  Future<List<PendingAttachment>> pasteFiles() async =>
      const <PendingAttachment>[];

  @override
  Future<List<PendingAttachment>> droppedFiles(
    List<DropwellFile> files,
  ) async => const <PendingAttachment>[];
}
