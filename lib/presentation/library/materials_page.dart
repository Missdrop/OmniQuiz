// Selection changes future generation; original files and saved questions remain intact.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../l10n/localization.dart';
import '../shared/widgets.dart';
import 'library_view_model.dart';

class MaterialsPage extends StatelessWidget {
  const MaterialsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LibraryViewModel>();
    final l = context.l10n;
    return PageFrame(
      eyebrow: l.library,
      title: l.manageMaterials,
      subtitle: l.materialSelectionHelp,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/library'),
            icon: const Icon(Icons.arrow_back),
            label: Text(l.backToLibrary),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: vm.busy ? null : () => vm.import(),
              icon: const Icon(Icons.add),
              label: Text(l.importFiles),
            ),
            if (vm.canImportZip)
              OutlinedButton.icon(
                onPressed: vm.busy ? null : vm.importZip,
                icon: const Icon(Icons.folder_zip_outlined),
                label: Text(l.importZip),
              ),
            if (vm.supportsDirectories && vm.files == null)
              OutlinedButton.icon(
                onPressed: vm.busy ? null : () => vm.import(directory: true),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l.importFolder),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          vm.canImportZip ? l.zipSupportedFiles : l.supportedFiles,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        if (vm.busy) const LinearProgressIndicator(),
        if (vm.scanning && vm.scanProgress != null) ...[
          Text(
            l.scanProgress(vm.scanProgress!.checked, vm.scanProgress!.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: vm.cancelScan,
              icon: const Icon(Icons.stop),
              label: Text(l.cancelScan),
            ),
          ),
        ],
        if (vm.message != null)
          Notice(vm.message!, onDismiss: vm.dismissMessage),
        if (vm.totalDocuments == 0)
          EmptyCard(
            icon: Icons.menu_book_outlined,
            title: l.libraryEmptyTitle,
            body: l.libraryEmptyBody,
            action: OutlinedButton(
              onPressed: vm.busy
                  ? null
                  : () => vm.import(
                      sample: true,
                      chineseSample: l.localeName == 'zh',
                    ),
              child: Text(l.trySample),
            ),
          ),
        if (vm.totalDocuments > 0) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.materialSelectionCount(
                  vm.enabledDocuments.length,
                  vm.totalDocuments,
                ),
              ),
              OutlinedButton(
                onPressed: vm.busy
                    ? null
                    : () => vm.selectDocuments(
                        vm.documents.map((doc) => doc.id),
                        true,
                        restoreExcluded: true,
                      ),
                child: Text(l.selectAllMaterials),
              ),
              OutlinedButton(
                onPressed: vm.busy
                    ? null
                    : () => vm.selectDocuments(
                        vm.documents.map((doc) => doc.id),
                        false,
                      ),
                child: Text(l.deselectAllMaterials),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        for (final doc in vm.documents)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                leading: Checkbox(
                  value: doc.enabled,
                  onChanged: vm.busy
                      ? null
                      : (value) => vm.selectDocuments([doc.id], value ?? false),
                ),
                title: Text(
                  doc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${vm.missingOrigins.contains(doc.origin) ? '${l.sourceMissing}\n' : ''}'
                  '${l.documentDetails(doc.chunkCount, MaterialLocalizations.of(context).formatMediumDate(doc.importedAt.toLocal()))}',
                ),
                onTap: vm.busy
                    ? null
                    : () => vm.selectDocuments([doc.id], !doc.enabled),
                trailing: IconButton(
                  tooltip: l.viewMaterial,
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => _preview(context, vm, doc),
                ),
              ),
            ),
          ),
        // Show legacy exclusions in this same list, unchecked, without a separate panel.
        for (final item in vm.excluded.entries.where(
          (entry) => !vm.documents.any((doc) => doc.origin == entry.key),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                leading: Checkbox(
                  value: false,
                  onChanged: vm.busy ? null : (_) => vm.include(item.key),
                ),
                title: Text(item.value),
                onTap: vm.busy ? null : () => vm.include(item.key),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _preview(
    BuildContext context,
    LibraryViewModel vm,
    StudyDocument doc,
  ) async {
    final chunks = await vm.source(doc.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(doc.name),
        content: SizedBox(
          width: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final chunk in chunks) ...[
                Text(
                  context.l10n.sourceLocation(chunk.location),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(chunk.text),
                const Divider(height: 32),
              ],
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
  }
}
