import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'library_view_model.dart';
import '../shared/widgets.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LibraryViewModel>();
    final stats = vm.stats;
    return PageFrame(
      eyebrow: 'Your learning space',
      title: 'A little practice. A lot of progress.',
      subtitle:
          'Bring your notes. Build understanding, one question at a time.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(
              context,
              '${stats.documents}',
              'Documents',
              Icons.library_books_outlined,
            ),
            _stat(
              context,
              '${stats.ready}',
              'Questions ready',
              Icons.auto_awesome_outlined,
            ),
            _stat(
              context,
              '${stats.attempts}',
              'Answers given',
              Icons.check_circle_outline,
            ),
            _stat(
              context,
              '${stats.review}',
              'To revisit',
              Icons.history_rounded,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: vm.busy ? null : () => vm.import(),
              icon: const Icon(Icons.add),
              label: const Text('Import files'),
            ),
            if (vm.supportsDirectories)
              OutlinedButton.icon(
                onPressed: vm.busy ? null : () => vm.import(directory: true),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Import folder'),
              ),
            TextButton.icon(
              onPressed: () => context.go('/practice'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to practice'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'TXT, Markdown & text PDF · up to 20 MB per file',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        if (vm.busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        if (vm.message != null) Notice(vm.message!),
        if (vm.documents.isEmpty)
          EmptyCard(
            icon: Icons.menu_book_outlined,
            title: 'Your next chapter starts here',
            body: 'Import a document to turn it into practice questions.\nYour materials stay on this device until you choose to generate.',
            action: TextButton(
              onPressed: vm.busy ? null : () => vm.import(sample: true),
              child: const Text('Try sample notes'),
            ),
          ),
        for (final doc in vm.documents)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: const CircleAvatar(
                child: Icon(Icons.description_outlined),
              ),
              title: Text(doc.name),
              subtitle: Text(
                '${doc.chunkCount} source excerpts · imported ${doc.importedAt.toLocal().toString().split(' ').first}',
              ),
              onTap: () async {
                final chunks = await vm.source(doc.id);
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(doc.name),
                    content: SizedBox(
                      width: 640,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in chunks) ...[
                              Text(
                                c.location,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(c.text),
                              const Divider(height: 32),
                            ],
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              trailing: IconButton(
                tooltip: 'Remove document',
                onPressed: vm.busy
                    ? null
                    : () async {
                        final remove = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove this document?'),
                            content: const Text(
                              'Its questions will leave the practice and review queues. Your answer history will be retained.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (remove == true) await vm.remove(doc.id);
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 600
        ? (MediaQuery.sizeOf(context).width - 52) / 2
        : 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    ),
  );
}
