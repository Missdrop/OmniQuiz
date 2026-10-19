import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../application/ports/repositories.dart';
import '../../domain/study_library.dart';
import '../persistence/library_catalog.dart';
import '../platform/library_files.dart';
import 'backup_database.dart';
import 'backup_manifest.dart';

/// Builds detached copies first, then publishes the entire restored catalog
/// in one write. Failure removes only the newly created directories.
class BackupRestore {
  BackupRestore(this.catalog, this.stage);
  final LibraryCatalog catalog;
  final String stage;
  final List<Directory> _created = [];

  Future<int> apply(BackupManifest manifest) async {
    var published = false;
    try {
      final restored = <StudyLibrary>[];
      for (final record in manifest.libraries) {
        restored.add(await _library(record));
      }
      await catalog.addRestored(restored);
      published = true;
      return restored.length;
    } finally {
      if (!published) {
        for (final directory in _created) {
          if (await directory.exists()) await directory.delete(recursive: true);
        }
      }
    }
  }

  Future<StudyLibrary> _library(BackupLibrary record) async {
    final id = const Uuid().v4();
    final directory = Directory(p.join(catalog.root, 'libraries', id));
    await directory.create(recursive: true);
    _created.add(directory);
    final materials = await Directory(p.join(directory.path, 'materials'))
        .create();
    final name =
        '${record.name.substring(0, record.name.length.clamp(0, 65))} (restored)';
    final library = StudyLibrary(id: id, name: name, directory: materials.path);
    final copy = await File(p.join(stage, record.database))
        .copy(catalog.databasePath(library));
    final origins = await _materials(record.files, materials.path);
    BackupDatabase.rebaseOrigins(copy.path, id, origins);
    return library;
  }

  Future<Map<String, String>> _materials(
    List<BackupMaterial> files,
    String directory,
  ) async {
    final origins = <String, String>{};
    final writer = DirectoryLibraryFiles(directory);
    for (final file in files) {
      final stored = await writer.store(
        ImportInput(
          name: file.path,
          origin: '',
          bytes: await File(p.join(stage, file.entry)).readAsBytes(),
        ),
        preserveDirectories: true,
      );
      origins[file.origin] = stored.origin;
    }
    return origins;
  }
}
