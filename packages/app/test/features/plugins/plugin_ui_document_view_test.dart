import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/src/shared/presentation/tinest_status_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

void main() {
  testWidgets(
    'renders every allowlisted node and dispatches host-owned actions',
    (tester) async {
      final actions = <PluginUiActionDto>[];
      const document = PluginUiDocumentDto(
        id: 'document',
        pluginId: 'example.controls',
        revisionHash: 'revision',
        slot: PluginUiSlot.agentSettings,
        root: <String, dynamic>{
          'type': 'section',
          'title': 'Controls',
          'description': 'Native host controls',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': 'Plain text'},
            <String, dynamic>{
              'type': 'markdown',
              'text': '**Markdown text**',
            },
            <String, dynamic>{
              'type': 'code',
              'code': 'print("hello")',
              'language': 'lua',
            },
            <String, dynamic>{
              'type': 'diff',
              'code': '- old\n+ new',
            },
            <String, dynamic>{
              'type': 'alert',
              'title': 'Attention',
              'description': 'Review this value.',
              'variant': 'warning',
            },
            <String, dynamic>{
              'type': 'row',
              'children': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'badge',
                  'text': 'Ready',
                  'variant': 'success',
                },
                <String, dynamic>{
                  'type': 'progress',
                  'label': 'Progress',
                  'value': 50,
                },
              ],
            },
            <String, dynamic>{
              'type': 'disclosure',
              'title': 'Details',
              'open': true,
              'children': <Map<String, dynamic>>[
                <String, dynamic>{'type': 'text', 'text': 'Hidden detail'},
              ],
            },
            <String, dynamic>{
              'type': 'field',
              'id': 'query',
              'label': 'Query',
              'value': 'initial',
            },
            <String, dynamic>{
              'type': 'switch',
              'id': 'enabled',
              'label': 'Enabled',
              'value': true,
              'actionId': 'toggle',
            },
            <String, dynamic>{
              'type': 'select',
              'id': 'mode',
              'label': 'Mode',
              'value': 'safe',
              'options': <Map<String, dynamic>>[
                <String, dynamic>{'value': 'safe', 'label': 'Safe'},
                <String, dynamic>{'value': 'fast', 'label': 'Fast'},
              ],
            },
            <String, dynamic>{
              'type': 'button',
              'label': 'Apply',
              'actionId': 'apply',
              'intent': 'primary',
            },
          ],
        },
      );

      await tester.pumpWidget(
        _TestApp(
          child: SingleChildScrollView(
            child: PluginUiDocumentView(
              document: document,
              invalidDocumentLabel: 'Unsupported plugin interface',
              invalidDocumentDescription: 'Open the raw document',
              onAction: (action) async {
                actions.add(action);
                return document;
              },
            ),
          ),
        ),
      );

      expect(find.byType(TRCard), findsOneWidget);
      expect(find.byType(TRCodeBlock), findsNWidgets(2));
      expect(find.byType(TRAlert), findsOneWidget);
      expect(find.byType(TRBadge), findsOneWidget);
      expect(find.byType(TRProgress), findsOneWidget);
      expect(find.byType(TRCollapsible), findsOneWidget);
      expect(find.byType(TRTextField), findsOneWidget);
      expect(find.byType(TRSwitch), findsOneWidget);
      expect(find.byType(TRSelect<String>), findsOneWidget);
      expect(
        tester
            .widget<TRSelect<String>>(find.byType(TRSelect<String>))
            .presentation,
        isA<TRSelectLayerPresentation>(),
      );

      await tester.ensureVisible(find.widgetWithText(TRButton, 'Apply'));
      await tester.tap(find.widgetWithText(TRButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(actions, hasLength(1));
      expect(actions.single.actionId, 'apply');
      expect(
        actions.single.data,
        containsPair(
          'values',
          <String, dynamic>{
            'query': 'initial',
            'enabled': true,
            'mode': 'safe',
          },
        ),
      );
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'falls back to a generic disclosure for an invalid document',
    (tester) async {
      const document = PluginUiDocumentDto(
        id: 'invalid',
        pluginId: 'example.invalid',
        revisionHash: 'revision',
        slot: PluginUiSlot.timeline,
        root: <String, dynamic>{
          'type': 'iframe',
          'src': 'https://untrusted.example',
        },
      );

      await tester.pumpWidget(
        const _TestApp(
          child: PluginUiDocumentView(
            document: document,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
          ),
        ),
      );

      expect(find.byType(TRCollapsible), findsOneWidget);
      expect(find.text('Unsupported plugin interface'), findsOneWidget);
      expect(find.byType(TRButton), findsNothing);
      expect(find.byType(TRSwitch), findsNothing);
      expect(find.bySemanticsLabel('Unsupported plugin interface'), findsOne);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'renders the pinned context-compaction timeline snapshot',
    (tester) async {
      const document = PluginUiDocumentDto(
        id: 'context-status',
        pluginId: 'tinest.context',
        revisionHash: 'context-revision',
        slot: PluginUiSlot.timeline,
        root: <String, dynamic>{
          'type': 'alert',
          'id': 'context-status',
          'title': 'Compacting context',
          'description':
              'The Agent driver is summarizing and replacing its model '
              'history.',
        },
      );

      await tester.pumpWidget(
        const _TestApp(
          child: PluginUiDocumentView(
            document: document,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
          ),
        ),
      );

      expect(find.byType(TRAlert), findsOneWidget);
      expect(find.text('Compacting context'), findsOneWidget);
      expect(
        find.text(
          'The Agent driver is summarizing and replacing its model history.',
        ),
        findsOneWidget,
      );
    },
    tags: const <String>[
      'feature_test__context_compaction__widget',
      'feature_test__plugin_ui__widget',
    ],
  );

  testWidgets(
    'keeps native semantics and layout across themes locales and large text',
    (tester) async {
      const document = PluginUiDocumentDto(
        id: 'accessible',
        pluginId: 'example.accessible',
        revisionHash: 'revision',
        slot: PluginUiSlot.dialog,
        root: <String, dynamic>{
          'type': 'section',
          'title': 'Controls',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'field',
              'id': 'name',
              'label': 'Name',
              'value': 'Tinest',
            },
            <String, dynamic>{
              'type': 'button',
              'label': 'Save',
              'actionId': 'save',
            },
          ],
        },
      );

      for (final locale in const <Locale>[
        Locale('en'),
        Locale('ko'),
        Locale('ja'),
      ]) {
        for (final mode in ThemeMode.values) {
          await tester.pumpWidget(
            _TestApp(
              locale: locale,
              themeMode: mode,
              textScaler: const TextScaler.linear(2),
              child: const PluginUiDocumentView(
                document: document,
                semanticLabel: 'Plugin controls',
                invalidDocumentLabel: 'Unsupported plugin interface',
                invalidDocumentDescription: 'Open the raw document',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.bySemanticsLabel('Plugin controls'), findsOneWidget);
          expect(find.byType(TRTextField), findsOneWidget);
          expect(find.widgetWithText(TRButton, 'Save'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'a tree nests its own items and the host owns the indentation',
    (tester) async {
      // Depth is a property of the tree, not of a row. A plugin that had to
      // send a depth number would be reimplementing the flattening every
      // host already does, and the host could never add a tree affordance
      // without a new node type.
      const document = PluginUiDocumentDto(
        id: 'tree',
        pluginId: 'example.tree',
        revisionHash: 'revision',
        slot: PluginUiSlot.conversationStatus,
        root: <String, dynamic>{
          'type': 'tree',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'tree_item',
              'label': 'reviewer',
              'description': '/root/reviewer',
              'status': 'running',
              'children': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'tree_item',
                  'label': 'linter',
                  'description': '/root/reviewer/linter',
                  'status': 'blocked',
                },
                <String, dynamic>{
                  'type': 'tree_item',
                  'label': 'builder',
                  'description': '/root/reviewer/builder',
                  'status': 'failed',
                },
              ],
            },
          ],
        },
      );

      await tester.pumpWidget(
        const _TestApp(
          themeMode: ThemeMode.dark,
          child: PluginUiDocumentView(
            document: document,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('reviewer'), findsOneWidget);
      expect(find.text('linter'), findsOneWidget);
      expect(find.text('builder'), findsOneWidget);
      expect(find.text('/root/reviewer/linter'), findsOneWidget);
      // A nested item sits further in than its parent, and the host is what
      // decided by how much.
      final parentLabel = tester.getTopLeft(find.text('reviewer')).dx;
      final childLabel = tester.getTopLeft(find.text('linter')).dx;
      expect(childLabel, greaterThan(parentLabel));
      // The plugin said "running" and "blocked"; the host chose the spinner
      // and the attention icon, and named them in the reader's language.
      expect(
        tester
            .widgetList<TinestStatusIcon>(find.byType(TinestStatusIcon))
            .map((icon) => icon.status),
        <TinestStatus>[
          TinestStatus.running,
          TinestStatus.blocked,
          TinestStatus.failed,
        ],
      );
      expect(find.byType(TRSpinner), findsOneWidget);
      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .map((icon) => icon.semanticLabel),
        <String?>[testL10n.statusBlocked, testL10n.statusFailed],
      );
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((icon) => icon.color),
        <Color?>[
          testDarkTheme.extension<TinyrackThemeData>()!.warningForeground,
          testDarkTheme.extension<TinyrackThemeData>()!.dangerForeground,
        ],
      );
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'a composer drawer is framed by the host, not by the document',
    (tester) async {
      const root = <String, dynamic>{
        'type': 'disclosure',
        'title': '2 subagents',
        'summary': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'badge',
            'text': '2 running',
            'variant': 'info',
          },
        ],
        'children': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': 'reviewer'},
        ],
      };
      const drawer = PluginUiDocumentDto(
        id: 'drawer',
        pluginId: 'example.drawer',
        revisionHash: 'revision',
        slot: PluginUiSlot.composerDrawer,
        root: root,
      );
      const inline = PluginUiDocumentDto(
        id: 'inline',
        pluginId: 'example.drawer',
        revisionHash: 'revision',
        slot: PluginUiSlot.conversationStatus,
        root: root,
      );

      await tester.pumpWidget(
        const _TestApp(
          child: PluginUiDocumentView(
            document: drawer,
            maxContentHeight: 120,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<TRCollapsible>(find.byType(TRCollapsible)).attachedEdge,
        TRCollapsibleAttachedEdge.bottom,
      );
      // The summary rides in the trigger, so a collapsed drawer still says
      // how many agents are running.
      expect(find.text('2 subagents'), findsOneWidget);
      expect(find.widgetWithText(TRBadge, '2 running'), findsOneWidget);

      await tester.pumpWidget(
        const _TestApp(
          child: PluginUiDocumentView(
            document: inline,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
          ),
        ),
      );
      await tester.pump();

      // The same document in another slot is free-standing: the framing is a
      // fact about the surface, and the plugin never chose it.
      expect(
        tester.widget<TRCollapsible>(find.byType(TRCollapsible)).attachedEdge,
        TRCollapsibleAttachedEdge.none,
      );
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'an activation intent reaches the host and an unknown one fails closed',
    (tester) async {
      final intents = <PluginUiIntent>[];
      const document = PluginUiDocumentDto(
        id: 'intent',
        pluginId: 'example.intent',
        revisionHash: 'revision',
        slot: PluginUiSlot.composerDrawer,
        root: <String, dynamic>{
          'type': 'tree',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'tree_item',
              'label': 'reviewer',
              'onActivate': <String, dynamic>{
                'type': 'open_session',
                'sessionId': 'child-1',
              },
            },
          ],
        },
      );

      await tester.pumpWidget(
        _TestApp(
          child: PluginUiDocumentView(
            document: document,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
            onIntent: intents.add,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('reviewer'));
      await tester.pumpAndSettle();

      expect(intents, hasLength(1));
      expect(intents.single, isA<PluginUiOpenSessionIntent>());
      expect(
        (intents.single as PluginUiOpenSessionIntent).sessionId,
        'child-1',
      );

      // An intent the host does not know is not a row that quietly does
      // nothing; it is a document the host cannot trust to draw at all.
      const forged = PluginUiDocumentDto(
        id: 'forged',
        pluginId: 'example.intent',
        revisionHash: 'revision',
        slot: PluginUiSlot.composerDrawer,
        root: <String, dynamic>{
          'type': 'tree',
          'children': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'tree_item',
              'label': 'reviewer',
              'onActivate': <String, dynamic>{
                'type': 'open_url',
                'url': 'https://untrusted.example',
              },
            },
          ],
        },
      );

      await tester.pumpWidget(
        _TestApp(
          child: PluginUiDocumentView(
            document: forged,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
            onIntent: intents.add,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unsupported plugin interface'), findsOneWidget);
      expect(find.text('reviewer'), findsNothing);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'uses the native keyboard action path',
    (tester) async {
      const document = PluginUiDocumentDto(
        id: 'keyboard',
        pluginId: 'example.keyboard',
        revisionHash: 'revision',
        slot: PluginUiSlot.dialog,
        root: <String, dynamic>{
          'type': 'button',
          'label': 'Run',
          'actionId': 'run',
        },
      );
      final actions = <PluginUiActionDto>[];
      await tester.pumpWidget(
        _TestApp(
          child: PluginUiDocumentView(
            document: document,
            invalidDocumentLabel: 'Unsupported plugin interface',
            invalidDocumentDescription: 'Open the raw document',
            onAction: (action) async {
              actions.add(action);
              return document;
            },
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(actions.map((action) => action.actionId), <String>['run']);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
    this.locale = testLocale,
    this.themeMode,
    this.textScaler = TextScaler.noScaling,
  });

  final Widget child;
  final Locale locale;
  final ThemeMode? themeMode;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: testLightTheme,
    darkTheme: testDarkTheme,
    locale: locale,
    themeMode: themeMode,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(TRSpacing.medium),
          child: child,
        ),
      ),
    ),
  );
}
