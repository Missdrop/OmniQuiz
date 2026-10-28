// Displays an active practice session, answer explanations and optional authoring controls.

import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'practice_view_model.dart';
import '../library/library_view_model.dart';
import '../shared/widgets.dart';
import '../shared/support_links.dart';
import 'guidance_view_model.dart';
import 'guidance_dialog.dart';
import 'source_viewer.dart';
import 'generation_progress.dart';
import '../../domain/models.dart';
import '../settings/connection_manager.dart';

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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PracticeViewModel>();
    final library = context.watch<LibraryViewModel>();
    final guidance = context.watch<GuidanceViewModel>();
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
        const ConnectionSummary(compact: true),
        if (!vm.reviewing)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(vm.scope),
                  initialValue: library.documents.any((d) => d.id == vm.scope)
                      ? vm.scope
                      : '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.practiceScope,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.l10n.allMaterials),
                    ),
                    ...library.documents.map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: vm.busy
                      ? null
                      : (v) => vm.changeScope(v == '' ? null : v),
                ),
              ),
              if (vm.active)
                OutlinedButton.icon(
                  onPressed: vm.endPractice,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(context.l10n.endPractice),
                )
              else
                FilledButton.icon(
                  onPressed: library.busy || guidance.busy || !widget.hasLibrary
                      ? null
                      : vm.startPractice,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.l10n.startPractice),
                ),
              if (vm.active && !vm.coordinator.enabled && !generation.running)
                TextButton.icon(
                  onPressed: vm.startPractice,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retryPractice),
                ),
              Chip(
                label: Text(context.l10n.readyCount(vm.readyCount)),
                avatar: const Icon(Icons.offline_pin_outlined, size: 18),
              ),
              OutlinedButton.icon(
                onPressed:
                    !widget.hasLibrary ||
                        library.busy ||
                        guidance.busy ||
                        vm.busy
                    ? null
                    : () async {
                        await guidance.load();
                        if (!context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              ChangeNotifierProvider<GuidanceViewModel>.value(
                                value: guidance,
                                child: const GuidanceDialog(),
                              ),
                        );
                      },
                icon: const Icon(Icons.tune),
                label: Text(context.l10n.guidanceTitle),
              ),
            ],
          )
        else
          TextButton.icon(
            onPressed: vm.leaveReview,
            icon: const Icon(Icons.arrow_back),
            label: Text(context.l10n.backToFresh),
          ),
        const SizedBox(height: 20),
        if (!vm.reviewing && !guidance.value.isEmpty)
          Text(
            context.l10n.guidanceEnabled,
            style: TextStyle(color: scheme.primary),
          ),
        if (!vm.reviewing) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.practiceSessionHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (vm.active && generation.running)
          GenerationProgress(status: generation, available: vm.readyCount),
        if (!vm.reviewing && vm.active && !generation.running)
          Notice(
            vm.coordinator.enabled && !generation.running
                ? context.l10n.practiceAutoReady
                : generation.message,
            error: generation.error,
          ),
        if (vm.message != null) Notice(vm.message!, error: true),
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
            action: Wrap(
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
                      child: Semantics(
                        selected: vm.selected == option.id,
                        button: true,
                        child: OutlinedButton(
                          onPressed: vm.answered || vm.busy
                              ? null
                              : () => vm.answer(option.id),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(18),
                            disabledForegroundColor: scheme.onSurface,
                            backgroundColor:
                                vm.answered && option.id == q.correctOptionId
                                ? scheme.secondaryContainer
                                : vm.answered && vm.selected == option.id
                                ? scheme.errorContainer
                                : vm.selected == option.id
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerLow,
                            side: BorderSide(
                              color: vm.selected == option.id
                                  ? Theme.of(context).colorScheme.primary
                                  : scheme.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.id.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              if (vm.answered && option.id == q.correctOptionId)
                                const Icon(Icons.check_circle_outline),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (vm.answered)
                        FilledButton(
                          onPressed: vm.busy ? null : vm.next,
                          child: Text(context.l10n.nextQuestion),
                        ),
                      if (vm.busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      for (final vote in [
                        QuestionRating.good,
                        QuestionRating.bad,
                      ])
                        TextButton.icon(
                          onPressed: vm.busy ? null : () => vm.rate(vote),
                          icon: Icon(
                            vote == QuestionRating.good
                                ? (vm.rating == vote
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined)
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
                        onPressed: vm.busy
                            ? null
                            : () => _reportError(context, vm),
                        icon: const Icon(Icons.help_outline),
                        label: Text(context.l10n.questionError),
                      ),
                    ],
                  ),
                  if (vm.rating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.l10n.feedbackNextGeneration,
                        style: Theme.of(context).textTheme.bodySmall,
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
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.sourceName(q.source.documentName),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.sourceLocation(q.source.location),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '“${q.quote}”',
                      style: const TextStyle(
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => SourceViewer(
                          source: q.source,
                          materials: library.materials,
                          libraryDirectory: library.files?.directory,
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(context.l10n.fullSource),
                    ),
                    Text(
                      context.l10n.aiDisclaimer,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
