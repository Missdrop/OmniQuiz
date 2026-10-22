import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../domain/study_library.dart';
import '../domain/models.dart';
import '../infrastructure/persistence/database.dart';
import '../infrastructure/persistence/library_catalog.dart';
import '../infrastructure/platform/document_access.dart';
import '../infrastructure/platform/library_files.dart';
import '../l10n/localization.dart';
import '../presentation/library/create_library_dialog.dart';
import '../infrastructure/platform/folder_permissions.dart';
import 'app.dart';
import 'dependencies.dart';
import '../infrastructure/backup/library_backup.dart';
import '../infrastructure/platform/backup_actions.dart';
import '../presentation/backup/backup_panel.dart';

/// Replaces the complete study session on a switch, including its view models.
class LibraryHost extends StatefulWidget {
  const LibraryHost({super.key, required this.catalog, required this.initial});
  final LibraryCatalog catalog;
  final AppDependencies initial;
  @override
  State<LibraryHost> createState() => _LibraryHostState();
}

class _LibraryHostState extends State<LibraryHost> with WidgetsBindingObserver {
  late AppDependencies _dependencies = widget.initial;
  bool _switching = false, _dialogOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_dependencies.library.scan());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_switching && !_dialogOpen) {
      unawaited(_dependencies.library.scan());
    }
  }

  Future<void> _select(StudyLibrary library) async {
    if (_switching ||
        library.id == widget.catalog.selectedId ||
        _dependencies.library.busy ||
        _dependencies.practice.busy ||
        _dependencies.settings.busy ||
        _dependencies.language.saving) {
      return;
    }
    setState(() {
      _switching = true;
      _error = null;
    });
    final old = _dependencies;
    AppDependencies? next;
    try {
      await old.coordinator.stop();
      final db = library.legacy
          ? widget.catalog.database
          : QuizDatabase(
              NativeDatabase.createInBackground(
                File(widget.catalog.databasePath(library)),
              ),
            );
      try {
        next = await AppDependencies.create(
          database: db,
          settingsDatabase: widget.catalog.database,
          ownsDatabase: !library.legacy,
          libraryFiles: DirectoryLibraryFiles(library.directory),
        );
      } catch (_) {
        if (!library.legacy) await db.close();
        rethrow;
      }
      if (!mounted) {
        await next.dispose();
        return;
      }
      await widget.catalog.select(library);
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _dependencies = next!;
      });
      // Let providers and router detach before disposing the previous session.
      await WidgetsBinding.instance.endOfFrame;
      await old.dispose();
      if (!mounted) return;
      await _dependencies.library.scan();
      if (mounted) setState(() => _switching = false);
    } catch (_) {
      if (next != null && !identical(next, _dependencies)) await next.dispose();
      if (mounted) {
        setState(() {
          _switching = false;
          _error = 'Could not open this library.';
        });
      }
    }
  }

  Future<void> _create(BuildContext context) async {
    _dialogOpen = true;
    final item = await showDialog<StudyLibrary>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateLibraryDialog(catalog: widget.catalog),
    );
    _dialogOpen = false;
    if (item != null && mounted) {
      setState(() {});
      await _select(item);
    }
  }

  Future<void> _grantFolderAccess() async {
    _dialogOpen = true;
    try {
      final chosen = await FilePicker.getDirectoryPath();
      if (chosen == null) return;
      final canonical = await Directory(chosen).resolveSymbolicLinks();
      if (!p.equals(
        p.normalize(canonical),
        p.normalize(widget.catalog.selected.directory),
      )) {
        if (mounted) setState(() => _error = 'grant');
        return;
      }
      await FolderPermissions.remember(canonical);
      if (mounted) setState(() => _error = null);
      await _dependencies.library.scan();
    } catch (_) {
      if (mounted) setState(() => _error = 'grant');
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _maintenance(Future<void> Function() action) async {
    if (_switching ||
        _dependencies.library.busy ||
        _dependencies.practice.busy ||
        _dependencies.settings.busy ||
        _dependencies.language.saving) {
      throw const AppFailure(
        'Finish the current operation before backing up or restoring.',
      );
    }
    setState(() => _switching = true);
    try {
      await _dependencies.coordinator.quiesce();
      await action();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Widget _controls(BuildContext context) {
    final locked =
        _switching ||
        _dependencies.library.busy ||
        _dependencies.practice.busy ||
        _dependencies.settings.busy ||
        _dependencies.language.saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                key: ValueKey(widget.catalog.selectedId),
                initialValue: widget.catalog.selectedId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.currentLibrary,
                ),
                items: [
                  for (final library in widget.catalog.libraries)
                    DropdownMenuItem(
                      value: library.id,
                      child: Text(
                        library.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: locked
                    ? null
                    : (id) {
                        if (id != null) {
                          unawaited(
                            _select(
                              widget.catalog.libraries.firstWhere(
                                (item) => item.id == id,
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
            OutlinedButton.icon(
              onPressed: locked ? null : () => _create(context),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(context.l10n.createLibrary),
            ),
            if (PlatformDocumentAccess().supportsDirectories)
              TextButton.icon(
                onPressed: locked ? null : _grantFolderAccess,
                icon: const Icon(Icons.folder_open),
                label: Text(context.l10n.grantFolderAccess),
              ),
            OutlinedButton.icon(
              onPressed: locked ? null : () => _dependencies.library.scan(),
              icon: const Icon(Icons.sync),
              label: Text(context.l10n.scanFolder),
            ),
            TextButton.icon(
              onPressed: locked
                  ? null
                  : () => _dependencies.library.scan(full: true),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(context.l10n.fullScan),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(context.l10n.libraryStorageDetails),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(widget.catalog.selected.directory),
            const SizedBox(height: 8),
            Text(context.l10n.libraryIsolationDescription),
          ],
        ),
        if (_error != null)
          Text(
            _error == 'grant'
                ? context.l10n.grantFolderError
                : context.l10n.openLibraryError,
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        OmniQuizApp(
          key: ObjectKey(_dependencies),
          dependencies: _dependencies,
          libraryControls: ListenableBuilder(
            listenable: Listenable.merge([
              _dependencies.library,
              _dependencies.practice,
              _dependencies.settings,
              _dependencies.language,
            ]),
            builder: (context, _) => _controls(context),
          ),
          currentLibraryName: widget.catalog.selected.name,
          settingsControls: BackupPanel(
            actions: PlatformBackupActions(
              LibraryBackup(
                widget.catalog,
                activeDatabase: _dependencies.database,
                activeId: widget.catalog.selectedId,
              ),
            ),
            runExclusive: _maintenance,
          ),
        ),
        if (_switching)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _dependencies.dispose().whenComplete(widget.catalog.database.close),
    );
    super.dispose();
  }
}
