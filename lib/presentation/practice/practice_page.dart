import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'practice_view_model.dart';
import '../library/library_view_model.dart';
import '../shared/widgets.dart';

class PracticePage extends StatelessWidget {
  const PracticePage({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PracticeViewModel>();
    final library = context.watch<LibraryViewModel>();
    final q = vm.current;
    final generation = vm.generation;
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
              if (vm.coordinator.enabled)
                OutlinedButton.icon(
                  onPressed: vm.stopGeneration,
                  icon: const Icon(Icons.pause),
                  label: Text(context.l10n.pauseGeneration),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.l10n.generateTitle),
                        content: Text(context.l10n.generateBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.l10n.start),
                          ),
                        ],
                      ),
                    );
                    if (proceed == true) await vm.startGeneration();
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(context.l10n.generateQuestions),
                ),
              Chip(
                label: Text(context.l10n.readyCount(vm.readyCount)),
                avatar: const Icon(Icons.offline_pin_outlined, size: 18),
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
        if (generation.running)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (!vm.reviewing) Notice(generation.message, error: generation.error),
        if (vm.message != null) Notice(vm.message!, error: true),
        if (q == null)
          EmptyCard(
            icon: vm.reviewing ? Icons.task_alt : Icons.psychology_outlined,
            title: vm.reviewing
                ? context.l10n.reviewCaughtUp
                : context.l10n.firstQuestion,
            body: vm.reviewing
                ? context.l10n.reviewCaughtUpBody
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
                              : () => vm.choose(option.id),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(18),
                            disabledForegroundColor: const Color(0xFF24382D),
                            backgroundColor:
                                vm.answered && option.id == q.correctOptionId
                                ? const Color(0xFFE2F1DD)
                                : vm.answered && vm.selected == option.id
                                ? const Color(0xFFFFE7DF)
                                : vm.selected == option.id
                                ? const Color(0xFFEAF0E5)
                                : Colors.white,
                            side: BorderSide(
                              color: vm.selected == option.id
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFFDCE2D8),
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
                      FilledButton(
                        onPressed: vm.busy
                            ? null
                            : vm.answered
                            ? vm.next
                            : vm.selected == null
                            ? null
                            : vm.submit,
                        child: Text(
                          vm.busy
                              ? context.l10n.saving
                              : vm.answered
                              ? context.l10n.nextQuestion
                              : context.l10n.checkAnswer,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: vm.busy
                            ? null
                            : () async {
                                final flag = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(context.l10n.hideQuestionTitle),
                                    content: Text(
                                      context.l10n.hideQuestionBody,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(context.l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(context.l10n.hideQuestion),
                                      ),
                                    ],
                                  ),
                                );
                                if (flag == true) await vm.flag();
                              },
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: Text(context.l10n.reportProblem),
                      ),
                    ],
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
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '“${q.quote}”',
                      style: const TextStyle(
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(context.l10n.fullSource),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SelectableText(
                            q.source.text,
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      context.l10n.aiDisclaimer,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
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
