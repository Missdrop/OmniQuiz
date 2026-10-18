import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'review_view_model.dart';
import '../practice/practice_view_model.dart';
import '../shared/widgets.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    return PageFrame(
      eyebrow: 'Mistakes become progress',
      title: 'Worth another look.',
      subtitle: 'Missed questions return here. Three correct reviews graduate a question from this queue.',
      children: [
        if (vm.error != null) Notice(vm.error!, error: true),
        if (vm.entries.isEmpty)
          const EmptyCard(
            icon: Icons.spa_outlined,
            title: 'A fresh start',
            body: 'Your missed questions will appear here. Keep practicing to discover what needs another look.',
          ),
        for (final entry in vm.entries)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.question.topic,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.question.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${entry.state.streak}/3 correct reviews · ${entry.state.mistakes} missed',
                      ),
                      Text(
                        entry.state.dueAt.isAfter(DateTime.now())
                            ? 'Due ${entry.state.dueAt.toLocal().toString().substring(0, 16)}'
                            : 'Due now',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: () async {
                          await context.read<PracticeViewModel>().review(
                            entry.question,
                          );
                          if (context.mounted) context.go('/practice');
                        },
                        child: Text(
                          entry.state.dueAt.isAfter(DateTime.now())
                              ? 'Review early'
                              : 'Review now',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
