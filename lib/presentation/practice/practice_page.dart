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
          ? 'Build lasting knowledge'
          : 'One question at a time',
      title: vm.reviewing ? 'A second look.' : 'Find your flow.',
      subtitle: vm.reviewing
          ? 'Recall it first. Then read the explanation.'
          : 'Fresh questions from your materials, ready before you need them.',
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
                  decoration: const InputDecoration(
                    labelText: 'Practice scope',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All materials'),
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
                  label: const Text('Pause generation'),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Generate practice questions?'),
                        content: const Text(
                          'Relevant excerpts will be sent to your configured AI provider. Generation uses your API balance and automatically replenishes a buffer of up to 20 questions while practice is active. You can pause at any time.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Start'),
                          ),
                        ],
                      ),
                    );
                    if (proceed == true) await vm.startGeneration();
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate questions'),
                ),
              Chip(
                label: Text('${vm.readyCount} ready'),
                avatar: const Icon(Icons.offline_pin_outlined, size: 18),
              ),
            ],
          )
        else
          TextButton.icon(
            onPressed: vm.leaveReview,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to fresh questions'),
          ),
        const SizedBox(height: 20),
        if (generation.running)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (!vm.reviewing) Notice(generation.message, error: generation.error),
        if (vm.message != null) Notice(vm.message!, error: true),
        if (q == null)
          EmptyCard(
            icon: vm.reviewing ? Icons.task_alt : Icons.psychology_outlined,
            title: vm.reviewing
                ? 'You’re caught up for now'
                : 'Ready for your first question?',
            body: vm.reviewing
                ? 'Come back when your next review is due, or choose another item from Review.'
                : 'Import your notes, connect an AI provider, then start generating.\nOnce saved, questions work offline too.',
            action: Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => context.go('/library'),
                  child: const Text('Open library'),
                ),
                TextButton(
                  onPressed: () =>
                      context.go(vm.reviewing ? '/review' : '/settings'),
                  child: Text(vm.reviewing ? 'Review queue' : 'Set up AI'),
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
                      const Chip(label: Text('Single choice')),
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
                              ? 'Saving…'
                              : vm.answered
                              ? 'Next question'
                              : 'Check answer',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: vm.busy
                            ? null
                            : () async {
                                final flag = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hide this question?'),
                                    content: const Text(
                                      'If the question is incorrect or ambiguous, remove it from practice and review. This report stays on your device.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Hide question'),
                                      ),
                                    ],
                                  ),
                                );
                                if (flag == true) await vm.flag();
                              },
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('Report a problem'),
                      ),
                    ],
                  ),
                  if (vm.answered) ...[
                    const Divider(height: 40),
                    Text(
                      q.isCorrect(vm.selected!)
                          ? 'Well done.'
                          : 'A useful mistake.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      q.explanation,
                      style: const TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SOURCE · ${q.source.documentName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.source.location,
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
                      title: const Text('Read the full source excerpt'),
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
                    const Text(
                      'AI-generated. Check the source if an answer seems wrong.',
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
