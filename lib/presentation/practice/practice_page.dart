// Displays an active practice session, answer explanations and optional authoring controls.

import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'practice_view_model.dart';
import '../library/library_view_model.dart';
import '../shared/widgets.dart';
import '../shared/support_links.dart';
import 'source_viewer.dart';
import 'choice_option.dart';
import 'generation_progress.dart';
import '../../domain/models.dart';
import 'practice_toolbar.dart';

/// Renders the current attempt without owning the paid generation loop.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key, this.hasLibrary = true});
  final bool hasLibrary;
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _questionKey = GlobalKey();
  String? _shownQuestion;
  Object? _dismissedGenerationNotice;

  Future<void> _reportError(BuildContext context, PracticeViewModel vm) async {
    final notes = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.questionError),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.questionFeedbackHelp),
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                maxLength: 1000,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.questionErrorNote,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => openSupportLink(
                dialog,
                aiReportUri,
                context.l10n.reportToDeveloper,
              ),
              child: Text(context.l10n.reportToDeveloper),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.l10n.markQuestionError),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await vm.rate(QuestionRating.error, note: notes.text.trim());
      }
    } finally {
      notes.dispose();
    }
  }

  /// Feedback stays beside the source controls, after the answer/explanation area.
  Widget _feedback(BuildContext context, PracticeViewModel vm) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (vm.busy)
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      for (final vote in [QuestionRating.good, QuestionRating.bad])
        TextButton.icon(
          onPressed: vm.busy ? null : () => vm.rate(vote),
          icon: Icon(
            vote == QuestionRating.good
                ? (vm.rating == vote ? Icons.thumb_up : Icons.thumb_up_outlined)
                : (vm.rating == vote
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined),
          ),
          label: Text(
            vote == QuestionRating.good
                ? context.l10n.questionGood
                : context.l10n.questionBad,
          ),
        ),
      TextButton.icon(
        onPressed: vm.busy ? null : () => _reportError(context, vm),
        icon: const Icon(Icons.help_outline),
        label: Text(context.l10n.questionError),
      ),
      if (vm.answered)
        FilledButton(
          onPressed: vm.busy ? null : vm.next,
          child: Text(context.l10n.nextQuestion),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PracticeViewModel>();
    final library = context.watch<LibraryViewModel>();
    final q = vm.active || vm.reviewing ? vm.current : null;
    if (q != null && q.id != _shownQuestion) {
      final scrollToQuestion = _shownQuestion != null;
      _shownQuestion = q.id;
      if (scrollToQuestion) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _questionKey.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(target);
          }
        });
      }
    }
    final generation = vm.generation;
    final scheme = Theme.of(context).colorScheme;
    return PageFrame(
      showHeader: false,
      compact: vm.active || vm.reviewing,
      eyebrow: vm.reviewing
          ? context.l10n.reviewPracticeEyebrow
          : context.l10n.practiceEyebrow,
      title: vm.reviewing
          ? context.l10n.reviewPracticeTitle
          : context.l10n.practiceTitle,
      subtitle: vm.reviewing
          ? context.l10n.reviewPracticeSubtitle
          : context.l10n.practiceSubtitle,
      children: [
        PracticeToolbar(hasLibrary: widget.hasLibrary),
        const Divider(height: 32),
        if (vm.active && generation.running)
          GenerationProgress(
            status: generation,
            available: vm.readyCount,
            compact: q != null,
          ),
        if (!vm.reviewing &&
            vm.active &&
            generation.error &&
            !generation.running &&
            !identical(_dismissedGenerationNotice, generation))
          Notice(
            generation.message,
            error: true,
            onDismiss: () =>
                setState(() => _dismissedGenerationNotice = generation),
          ),
        if (vm.message != null)
          Notice(vm.message!, error: true, onDismiss: vm.dismissMessage),
        if (q == null)
          EmptyCard(
            icon: vm.reviewing
                ? Icons.task_alt
                : vm.active
                ? Icons.hourglass_empty
                : Icons.psychology_outlined,
            title: vm.reviewing
                ? context.l10n.reviewCaughtUp
                : vm.active
                ? context.l10n.waitingForQuestion
                : context.l10n.firstQuestion,
            body: vm.reviewing
                ? context.l10n.reviewCaughtUpBody
                : vm.active
                ? context.l10n.waitingForQuestionBody
                : context.l10n.firstQuestionBody,
            action: vm.active
                ? null
                : Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/library'),
                        child: Text(context.l10n.openLibrary),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go(vm.reviewing ? '/review' : '/settings'),
                        child: Text(
                          vm.reviewing
                              ? context.l10n.reviewQueue
                              : context.l10n.setUpAi,
                        ),
                      ),
                    ],
                  ),
          ),
        if (q != null)
          Card(
            key: _questionKey,
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(q.topic)),
                      Chip(label: Text(context.l10n.singleChoice)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SelectableText(
                    q.prompt,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  for (final option in q.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChoiceOption(
                        label: option.id,
                        text: option.text,
                        selected: vm.selected == option.id,
                        correct: vm.answered && option.id == q.correctOptionId,
                        incorrect:
                            vm.answered &&
                            vm.selected == option.id &&
                            option.id != q.correctOptionId,
                        onPressed: vm.answered || vm.busy
                            ? null
                            : () => vm.answer(option.id),
                      ),
                    ),
                  if (vm.answered) ...[
                    const Divider(height: 40),
                    Text(
                      q.isCorrect(vm.selected!)
                          ? context.l10n.correctAnswer
                          : context.l10n.wrongAnswer,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      q.explanation,
                      style: const TextStyle(height: 1.7),
                    ),
                  ],
                  const Divider(height: 32),
                  SourceCitation(
                    key: ValueKey('source-${q.id}'),
                    source: q.source,
                    materials: library.materials,
                    libraryDirectory: library.files?.directory,
                    trailing: _feedback(context, vm),
                  ),
                  if (vm.rating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.l10n.feedbackNextGeneration,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.aiDisclaimer,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
