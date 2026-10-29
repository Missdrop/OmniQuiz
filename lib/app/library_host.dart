// Switches entire library sessions and waits for active work before closing database handles.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../domain/study_library.dart';
import '../domain/models.dart';
import '../infrastructure/persistence/library_catalog.dart';
import '../infrastructure/persistence/database.dart';
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
import '../presentation/updates/update_controller.dart';

/// Replaces the complete study session on a switch, including its view models.
class LibraryHost extends StatefulWidget {
  const LibraryHost({
    super.key,
    required this.catalog,
    required this.initial,
    this.updates,
    this.initialUnavailable = false,
  });
  final LibraryCatalog catalog;
  final AppDependencies initial;
  final UpdateController? updates;
  final bool initialUnavailable;
  @override
  State<LibraryHost> createState() => _LibraryHostState();
}

class _LibraryHostState extends State<LibraryHost> with WidgetsBindingObserver {
  late AppDependencies _dependencies = widget.initial;
  bool _switching = false, _dialogOpen = false;
  String? _error;
  late bool _unavailable = widget.initialUnavailable;
  bool get _hasLibrary => widget.catalog.selectedId.isNotEmpty && !_unavailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_unavailable) _error = 'open';
    widget.updates?.prepareToExit = () async {
      if (_switching ||
          _dialogOpen ||
          _dependencies.library.busy ||
          _dependencies.practice.busy ||
          _dependencies.settings.busy ||
          _dependencies.guidance.busy ||
          _dependencies.language.saving ||
          _dependencies.appearance.saving ||
          _dependencies.questionLanguage.saving) {
        throw const AppFailure(
          'Finish the current operation before installing an update.',
        );
      }
      await _dependencies.coordinator.quiesce();
      await _dependencies.library.stopScan();
    };
    unawaited(_dependencies.library.scan());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_switching && !_dialogOpen) {
      if (_dependencies.practice.active) return;
      unawaited(_dependencies.library.scan());
    }
  }

  Future<void> _select(StudyLibrary library) async {
    if (_switching ||
        (library.id == widget.catalog.selectedId && !_unavailable) ||
        _dependencies.library.busy ||
        _dependencies.practice.busy ||
        _dependencies.settings.busy ||
        _dependencies.guidance.busy ||
        _dependencies.language.saving ||
        _dependencies.appearance.saving ||
        _dependencies.questionLanguage.saving) {
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
      final db = await widget.catalog.openLibrary(library);
      try {
        next = await AppDependencies.create(
          database: db,
          settingsDatabase: widget.catalog.database,
          ownsDatabase: true,
          libraryFiles: DirectoryLibraryFiles(library.directory),
        );
      } catch (_) {
        await db.close();
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
        _unavailable = false;
      });
      // Let providers and router detach before disposing the previous session.
      await WidgetsBinding.instance.endOfFrame;
      await old.dispose();
      if (!mounted) return;
      await _dependencies.library.scan();
      if (mounted) setState(() => _switching = false);
    } catch (error, stack) {
      assert(() {
        debugPrint('Library open failed (${error.runtimeType}): $error');
        debugPrintStack(stackTrace: stack);
        return true;
      }());
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

  Future<void> _delete(BuildContext context) async {
    if (_switching || _dialogOpen || widget.catalog.selectedId.isEmpty) return;
    final library = widget.catalog.selected;
    var keepMaterials = true;
    _dialogOpen = true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final l = context.l10n;
          return AlertDialog(
            title: Text(l.deleteLibraryTitle(library.name)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.deleteLibraryBody),
                  const SizedBox(height: 12),
                  SelectableText(library.directory),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.keepLibraryMaterials),
                    value: keepMaterials,
                    onChanged: (value) =>
                        update(() => keepMaterials = value ?? true),
                  ),
                  Text(
                    keepMaterials
                        ? l.deleteLibraryKeepHelp
                        : l.deleteLibraryFolderWarning,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, keepMaterials),
                child: Text(l.deleteLibrary),
              ),
            ],
          );
        },
      ),
    );
    _dialogOpen = false;
    if (keep == null || !mounted) return;
    setState(() {
      _switching = true;
      _error = null;
    });
    final old = _dependencies;
    AppDependencies? empty;
    try {
      await old.coordinator.stop();
      await old.library.stopScan();
      empty = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        settingsDatabase: widget.catalog.database,
      );
      if (!mounted) {
        await empty.dispose();
        return;
      }
      // Detach every provider before disposing the session and removing its database.
      setState(() {
        _dependencies = empty!;
        _unavailable = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      await old.dispose();
      await widget.catalog.remove(library, keepMaterials: keep);
      if (!mounted) return;
      setState(() {
        _switching = false;
        _unavailable = widget.catalog.selectedId.isNotEmpty;
      });
      final next = widget.catalog.libraries.firstOrNull;
      if (next != null) await _select(next);
    } catch (error) {
      assert(() {
        debugPrint('Library deletion failed (${error.runtimeType}): $error');
        return true;
      }());
      if (empty != null && !identical(empty, _dependencies)) {
        await empty.dispose();
      }
      if (mounted) {
        setState(() {
          _switching = false;
          _error = error is AppFailure && error.message == 'Library removed, but some study data could not be deleted.'
              ? 'deleteCleanup'
              : 'delete';
        });
      }
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
      if (_unavailable) {
        await _select(widget.catalog.selected);
      } else {
        await _dependencies.library.scan();
      }
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
        _dependencies.guidance.busy ||
        _dependencies.language.saving ||
        _dependencies.appearance.saving ||
        _dependencies.questionLanguage.saving) {
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
    if (mounted && !_hasLibrary && widget.catalog.libraries.isNotEmpty) {
      await _select(widget.catalog.libraries.first);
    }
  }

  Widget _controls(BuildContext context) {
    final locked =
        _switching ||
        _dependencies.library.busy ||
        _dependencies.practice.busy ||
        _dependencies.settings.busy ||
        _dependencies.guidance.busy ||
        _dependencies.language.saving ||
        _dependencies.appearance.saving ||
        _dependencies.questionLanguage.saving;
    if (widget.catalog.libraries.isEmpty || widget.catalog.selectedId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.noLibrariesBody),
          if (_error != null)
            Text(
              _error == 'deleteCleanup'
                  ? context.l10n.deleteLibraryCleanupError
                  : context.l10n.deleteLibraryError,
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: locked ? null : () => _create(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(context.l10n.createLibrary),
          ),
        ],
      );
    }
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
            OutlinedButton.icon(
              onPressed: locked ? null : () => _delete(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.folder_delete_outlined),
              label: Text(context.l10n.deleteLibrary),
            ),
            if (PlatformDocumentAccess().supportsDirectories)
              OutlinedButton.icon(
                onPressed: locked ? null : _grantFolderAccess,
                icon: const Icon(Icons.folder_open),
                label: Text(context.l10n.grantFolderAccess),
              ),
            if (_unavailable)
              OutlinedButton.icon(
                onPressed: locked
                    ? null
                    : () => _select(widget.catalog.selected),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.reopenLibrary),
              ),
            OutlinedButton.icon(
              onPressed: locked || !_hasLibrary
                  ? null
                  : () => _dependencies.library.scan(),
              icon: const Icon(Icons.sync),
              label: Text(context.l10n.scanFolder),
            ),
            OutlinedButton.icon(
              onPressed: locked || !_hasLibrary
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
                : _error == 'delete'
                ? context.l10n.deleteLibraryError
                : _error == 'deleteCleanup'
                ? context.l10n.deleteLibraryCleanupError
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
          hasLibrary: _hasLibrary,
          updates: widget.updates,
          libraryControls: ListenableBuilder(
            listenable: Listenable.merge([
              _dependencies.library,
              _dependencies.practice,
              _dependencies.settings,
              _dependencies.guidance,
              _dependencies.language,
              _dependencies.appearance,
              _dependencies.questionLanguage,
            ]),
            builder: (context, _) => _controls(context),
          ),
          currentLibraryName: widget.catalog.selectedId.isNotEmpty
              ? widget.catalog.selected.name
              : null,
          settingsControls: BackupPanel(
            canExport: _hasLibrary,
            actions: PlatformBackupActions(
              LibraryBackup(
                widget.catalog,
                activeDatabase: _dependencies.database,
                activeId: _hasLibrary ? widget.catalog.selectedId : null,
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
    widget.updates?.dispose();
    unawaited(
      _dependencies.dispose().whenComplete(widget.catalog.database.close),
    );
    super.dispose();
  }
}
