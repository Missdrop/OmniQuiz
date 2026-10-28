// Displays spaced-review state and lets users practice due or early questions explicitly.

import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'review_view_model.dart';
import '../practice/practice_view_model.dart';
import '../shared/widgets.dart';

/// Presents saved mistakes and due dates without mutating review state on display.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    return PageFrame(
      eyebrow: context.l10n.reviewEyebrow,
      title: context.l10n.reviewTitle,
      subtitle: context.l10n.reviewSubtitle,
      children: [
        if (vm.error != null) Notice(vm.error!, error: true),
        if (vm.entries.isEmpty)
          EmptyCard(
            icon: Icons.spa_outlined,
            title: context.l10n.reviewEmptyTitle,
            body: context.l10n.reviewEmptyBody,
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
                        context.l10n.reviewProgress(
                          entry.state.streak,
                          entry.state.mistakes,
                        ),
                      ),
                      Text(
                        entry.state.dueAt.isAfter(DateTime.now())
                            ? context.l10n.dueDate(
                                '${MaterialLocalizations.of(context).formatMediumDate(entry.state.dueAt.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.state.dueAt.toLocal()))}',
                              )
                            : context.l10n.dueNow,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                              ? context.l10n.reviewEarly
                              : context.l10n.reviewNow,
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
