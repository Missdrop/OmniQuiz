// A compact dashboard: metrics open their working pages instead of listing every source here.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/localization.dart';
import '../shared/widgets.dart';
import 'library_view_model.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    this.controls,
    this.hasLibrary = true,
    this.unavailable = false,
  });
  final Widget? controls;
  final bool hasLibrary, unavailable;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LibraryViewModel>();
    final l = context.l10n;
    return PageFrame(
      eyebrow: l.libraryEyebrow,
      title: hasLibrary || unavailable ? l.libraryTitle : l.noLibrariesTitle,
      subtitle: l.librarySubtitle,
      children: [
        ?controls,
        if (hasLibrary)
          SummaryGrid(
            children: [
              _stat(
                context,
                '${vm.totalDocuments}',
                l.documents,
                Icons.library_books_outlined,
                '/library/materials',
                hint: l.materialsSelected(vm.enabledDocuments.length),
              ),
              _stat(
                context,
                '${vm.stats.ready}',
                l.questionsReady,
                Icons.auto_awesome_outlined,
                '/practice',
              ),
              _stat(
                context,
                '${vm.stats.attempts}',
                l.answersGiven,
                Icons.check_circle_outline,
                '/library/history',
              ),
              _stat(
                context,
                '${vm.stats.review}',
                l.toRevisit,
                Icons.history_rounded,
                '/review',
              ),
            ],
          ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    String route, {
    String? hint,
  }) => Card(
    key: ValueKey('stat:$route'),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (hint != null)
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
