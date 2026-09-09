import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Sentinel radio value standing for the always-present free-form option.
///
/// The agent never authors this choice, so it cannot collide with a label it
/// wrote: option values are prefixed with their index.
const String _otherValue = 'other';

/// Renders the questions one agent turn is blocked on.
///
/// Every question offers the agent's fixed choices plus a free-form answer, so
/// the user is never forced into an option that does not fit.
class ChatQuestionCard extends ConsumerStatefulWidget {
  /// Creates a [ChatQuestionCard].
  const new({required this.hostId, required this.request, super.key});

  /// Stable host profile containing the question's session.
  final String? hostId;

  /// The pending question rendered by this card.
  final UserQuestionRequestDto request;

  @override
  ConsumerState<ChatQuestionCard> createState() => _ChatQuestionCardState();
}

class _ChatQuestionCardState extends ConsumerState<ChatQuestionCard> {
  /// Chosen radio value per question id.
  final Map<String, String> _selected = <String, String>{};

  /// Free-form text per question id, used when [_otherValue] is selected.
  final Map<String, TextEditingController> _freeForm =
      <String, TextEditingController>{};

  int _activeQuestionIndex = 0;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    for (final controller in _freeForm.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String questionId) =>
      _freeForm.putIfAbsent(questionId, TextEditingController.new);

  bool _isAnswered(UserQuestionItemDto question) {
    final choice = _selected[question.id];
    if (choice == null) return false;
    if (choice != _otherValue) return true;
    return _controllerFor(question.id).text.trim().isNotEmpty;
  }

  /// The answers, or null while any question is still unanswered.
  List<UserQuestionAnswerDto>? get _answers {
    final answers = <UserQuestionAnswerDto>[];
    for (final question in widget.request.questions) {
      final choice = _selected[question.id];
      if (choice == null) return null;
      if (choice == _otherValue) {
        final text = _controllerFor(question.id).text.trim();
        if (text.isEmpty) return null;
        answers.add(
          UserQuestionAnswerDto(
            questionId: question.id,
            answer: text,
            isFreeForm: true,
          ),
        );
        continue;
      }
      answers.add(
        UserQuestionAnswerDto(
          questionId: question.id,
          answer: question.options[int.parse(choice)].label,
          isFreeForm: false,
        ),
      );
    }
    return answers;
  }

  Future<void> _submit(List<UserQuestionAnswerDto> answers) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(
            conversationControllerProvider(
              widget.hostId!,
              widget.request.sessionId,
            ).notifier,
          )
          .answerUserQuestion(widget.request.id, answers);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _selectAnswer(UserQuestionItemDto question, String value) {
    setState(() {
      _selected[question.id] = value;
      if (value != _otherValue &&
          widget.request.questions[_activeQuestionIndex].id == question.id &&
          _activeQuestionIndex < widget.request.questions.length - 1) {
        _activeQuestionIndex += 1;
      }
    });
  }

  void _runPrimaryAction() {
    final questions = widget.request.questions;
    final activeQuestion = questions[_activeQuestionIndex];
    if (_submitting || widget.hostId == null || !_isAnswered(activeQuestion)) {
      return;
    }
    if (_activeQuestionIndex < questions.length - 1) {
      setState(() => _activeQuestionIndex += 1);
      return;
    }
    final answers = _answers;
    if (answers != null) unawaited(_submit(answers));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final questions = widget.request.questions;
    final activeQuestion = questions[_activeQuestionIndex];
    final multipleQuestions = questions.length > 1;
    final lastQuestion = _activeQuestionIndex == questions.length - 1;
    final answers = _answers;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TRSpacing.extraSmall),
      child: TRCard(
        key: ValueKey<String>('chat-question-${widget.request.id}'),
        padding: TRCardPadding.none,
        variant: TRCardVariant.elevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (multipleQuestions)
              TRTabs(
                key: const ValueKey<String>('chat-question-tabs'),
                semanticLabel: l10n.chatQuestionNavigation,
                value: activeQuestion.id,
                onValueChange: (questionId) {
                  setState(
                    () => _activeQuestionIndex = questions.indexWhere(
                      (question) => question.id == questionId,
                    ),
                  );
                },
                tabs: <TRTabsTab>[
                  for (final question in questions)
                    TRTabsTab(
                      value: question.id,
                      label: question.header,
                      disabled: _submitting,
                      leading: _isAnswered(question)
                          ? Icon(
                              TinestIcons.check,
                              size: TRControlMetrics.iconSizeOf(
                                TinestUiDensity.defaultControlSize(context),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(TRSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _QuestionSection(
                    key: ValueKey<String>(activeQuestion.id),
                    question: activeQuestion,
                    selected: _selected[activeQuestion.id],
                    freeFormController: _controllerFor(activeQuestion.id),
                    showHeader: !multipleQuestions,
                    disabled: _submitting,
                    onChanged: (value) => _selectAnswer(activeQuestion, value),
                    onFreeFormChanged: (_) => setState(() {}),
                    onFreeFormSubmitted: (_) => _runPrimaryAction(),
                    textInputAction: lastQuestion
                        ? TextInputAction.done
                        : TextInputAction.next,
                  ),
                  const SizedBox(height: TRSpacing.small),
                  if (_error case final error?) ...<Widget>[
                    TRText('$error', color: TRTextColor.danger),
                    const SizedBox(height: TRSpacing.small),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TRButton(
                      key: const ValueKey<String>('chat-question-submit'),
                      intent: TRIntent.primary,
                      loading: _submitting,
                      loadingLabel: l10n.chatQuestionSubmitting,
                      onPressed:
                          _isAnswered(activeQuestion) &&
                              (!lastQuestion || answers != null) &&
                              !_submitting &&
                              widget.hostId != null
                          ? _runPrimaryAction
                          : null,
                      child: Text(
                        lastQuestion
                            ? l10n.chatQuestionSubmit
                            : l10n.chatQuestionNext,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  const new({
    required this.question,
    required this.selected,
    required this.freeFormController,
    required this.showHeader,
    required this.disabled,
    required this.onChanged,
    required this.onFreeFormChanged,
    required this.onFreeFormSubmitted,
    required this.textInputAction,
    super.key,
  });

  final UserQuestionItemDto question;
  final String? selected;
  final TextEditingController freeFormController;
  final bool showHeader;
  final bool disabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onFreeFormChanged;
  final ValueChanged<String> onFreeFormSubmitted;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: TRSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            TRText(question.header, variant: TRTextVariant.label),
            const SizedBox(height: TRSpacing.threeExtraSmall),
          ],
          TRText(question.question),
          const SizedBox(height: TRSpacing.small),
          TRRadioGroup(
            value: selected,
            disabled: disabled,
            onValueChange: onChanged,
            children: <TRRadio>[
              for (var index = 0; index < question.options.length; index += 1)
                TRRadio(
                  value: '$index',
                  label: Flexible(
                    child: _OptionLabel(option: question.options[index]),
                  ),
                ),
              TRRadio(
                value: _otherValue,
                label: TRText(l10n.chatQuestionOther),
              ),
            ],
          ),
          if (selected == _otherValue) ...<Widget>[
            const SizedBox(height: TRSpacing.small),
            TRTextField(
              key: ValueKey<String>('chat-question-other-${question.id}'),
              controller: freeFormController,
              enabled: !disabled,
              placeholder: l10n.chatQuestionOtherPlaceholder,
              onChanged: onFreeFormChanged,
              onSubmitted: onFreeFormSubmitted,
              textInputAction: textInputAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionLabel extends StatelessWidget {
  const new({required this.option});

  final UserQuestionOptionDto option;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      TRText(option.label),
      if (option.description.isNotEmpty)
        TRText(
          option.description,
          variant: TRTextVariant.caption,
          color: TRTextColor.muted,
        ),
    ],
  );
}
