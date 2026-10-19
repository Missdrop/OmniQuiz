import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../infrastructure/persistence/library_catalog.dart';
import '../../infrastructure/platform/document_access.dart';
import '../../infrastructure/platform/folder_permissions.dart';
import '../../l10n/localization.dart';

class CreateLibraryDialog extends StatefulWidget {
  const CreateLibraryDialog({super.key, required this.catalog});
  final LibraryCatalog catalog;
  @override
  State<CreateLibraryDialog> createState() => _CreateLibraryDialogState();
}

class _CreateLibraryDialogState extends State<CreateLibraryDialog> {
  final _name = TextEditingController();
  bool _external = false, _busy = false;
  String? _folder, _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() => _busy = true);
    try {
      final chosen = await FilePicker.getDirectoryPath();
      if (chosen != null) {
        final canonical = await Directory(chosen).resolveSymbolicLinks();
        await FolderPermissions.remember(canonical);
        if (mounted) setState(() => _folder = canonical);
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.createLibraryError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || (_external && _folder == null)) {
      setState(() => _error = context.l10n.libraryNameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final library = await widget.catalog.create(
        _name.text,
        directory: _external ? _folder : null,
      );
      if (mounted) Navigator.pop(context, library);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.createLibraryError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(context.l10n.createLibrary),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 80,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.libraryName,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _external,
                onChanged:
                    !_busy && PlatformDocumentAccess().supportsDirectories
                    ? (value) => setState(() {
                        _external = value;
                        _error = null;
                      })
                    : null,
                title: Text(context.l10n.useExistingFolder),
              ),
              if (_external)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.folder_open),
                  label: Text(context.l10n.chooseFolder),
                ),
              Text(
                _external
                    ? (_folder ?? context.l10n.folderIncludesSubfolders)
                    : context.l10n.managedFolderDescription,
              ),
              if (!PlatformDocumentAccess().supportsDirectories)
                Text(context.l10n.mobileLibraryDescription),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(context.l10n.create),
        ),
      ],
    ),
  );
}
