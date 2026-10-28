// Presents material import, status and exclusions; view models own disk and repository operations.

import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'library_view_model.dart';
import '../shared/widgets.dart';

/// Material-list presentation; imports, removals and scans are delegated to its view model.
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    this.controls,
    this.hasLibrary = true,
    this.unavailable = false,
  });
  final Widget? controls;
  final bool hasLibrary;
  final bool unavailable;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LibraryViewModel>();
    final stats = vm.stats;
    if (!hasLibrary) {
      return PageFrame(
        eyebrow: context.l10n.libraryEyebrow,
        title: unavailable
            ? context.l10n.libraryTitle
            : context.l10n.noLibrariesTitle,
        subtitle: context.l10n.librarySubtitle,
        children: [?controls],
      );
    }
    return PageFrame(
      eyebrow: context.l10n.libraryEyebrow,
      title: context.l10n.libraryTitle,
      subtitle: context.l10n.librarySubtitle,
      children: [
        ?controls,
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(
              context,
              '${stats.documents}',
              context.l10n.documents,
              Icons.library_books_outlined,
            ),
            _stat(
              context,
              '${stats.ready}',
              context.l10n.questionsReady,
              Icons.auto_awesome_outlined,
            ),
            _stat(
              context,
              '${stats.attempts}',
              context.l10n.answersGiven,
              Icons.check_circle_outline,
            ),
            _stat(
              context,
              '${stats.review}',
              context.l10n.toRevisit,
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
              label: Text(context.l10n.importFiles),
            ),
            if (vm.canImportZip)
              OutlinedButton.icon(
                onPressed: vm.busy ? null : vm.importZip,
                icon: const Icon(Icons.folder_zip_outlined),
                label: Text(context.l10n.importZip),
              ),
            if (vm.supportsDirectories && vm.files == null)
              OutlinedButton.icon(
                onPressed: vm.busy ? null : () => vm.import(directory: true),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(context.l10n.importFolder),
              ),
            if (vm.excluded.isNotEmpty)
              OutlinedButton.icon(
                onPressed: vm.busy ? null : () => _showExcluded(context, vm),
                icon: const Icon(Icons.restore_page_outlined),
                label: Text(context.l10n.excludedFiles(vm.excluded.length)),
              ),
            TextButton.icon(
              onPressed: () => context.go('/practice'),
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.l10n.goToPractice),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          vm.canImportZip
              ? context.l10n.zipSupportedFiles
              : context.l10n.supportedFiles,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (vm.busy)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        if (vm.scanning && vm.scanProgress != null) ...[
          Text(
            context.l10n.scanProgress(
              vm.scanProgress!.checked,
              vm.scanProgress!.name,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton.icon(
            onPressed: vm.cancelScan,
            icon: const Icon(Icons.stop),
            label: Text(context.l10n.cancelScan),
          ),
        ],
        if (vm.message != null) Notice(vm.message!),
        if (vm.documents.isEmpty)
          EmptyCard(
            icon: Icons.menu_book_outlined,
            title: context.l10n.libraryEmptyTitle,
            body: context.l10n.libraryEmptyBody,
            action: TextButton(
              onPressed: vm.busy
                  ? null
                  : () => vm.import(
                      sample: true,
                      chineseSample: context.l10n.localeName == 'zh',
                    ),
              child: Text(context.l10n.trySample),
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
                (vm.missingOrigins.contains(doc.origin)
                        ? '${context.l10n.sourceMissing}\n'
                        : '') +
                    context.l10n.documentDetails(
                      doc.chunkCount,
                      MaterialLocalizations.of(context)
                          .formatMediumDate(doc.importedAt.toLocal()),
                    ),
              ),
              onTap: () async {
                final chunks = await vm.source(doc.id);
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    scrollable: true,
                    title: Text(doc.name),
                    content: SizedBox(
                      width: 640,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in chunks) ...[
                              Text(
                                context.l10n.sourceLocation(c.location),
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
                        child: Text(context.l10n.close),
                      ),
                    ],
                  ),
                );
              },
              trailing: IconButton(
                tooltip: context.l10n.removeDocument,
                onPressed: vm.busy
                    ? null
                    : () async {
                        final remove = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            scrollable: true,
                            title: Text(context.l10n.removeDocumentTitle),
                            content: Text(
                              vm.files == null
                                  ? context.l10n.removeDocumentBody
                                  : context.l10n.removeIndexedDocumentBody,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(context.l10n.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(context.l10n.remove),
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

  Future<void> _showExcluded(BuildContext context, LibraryViewModel vm) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.excludedFiles(vm.excluded.length)),
        content: SizedBox(
          width: 520,
          height: vm.excluded.length > 4 ? 320 : vm.excluded.length * 72.0,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in vm.excluded.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(context, entry.key),
                    child: Text(context.l10n.restoreImport),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
    if (selected != null) await vm.include(selected);
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
