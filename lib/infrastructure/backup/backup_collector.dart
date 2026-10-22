import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../../domain/study_library.dart';
import '../persistence/database.dart';
import '../persistence/library_catalog.dart';
import '../persistence/repositories.dart';
import '../platform/library_files.dart';
import 'backup_archive.dart';
import 'backup_database.dart';
import 'backup_manifest.dart';

/// Collects one consistent DB snapshot plus source files for each library.
/// The caller pauses this installation's active workflows before collecting.
class BackupCollector {
  BackupCollector(
    this.catalog,
    this.stage, {
    this.activeDatabase,
    this.activeId,
  });
  final LibraryCatalog catalog;
  final String stage;
  final QuizDatabase? activeDatabase;
  final String? activeId;
  int _bytes = 0, _entries = 1, _missing = 0;

  Future<BackupManifest> collect() async {
    if (catalog.libraries.length > 100) {
      throw const AppFailure('Backup is too large.');
    }
    final libraries = <BackupLibrary>[];
    for (final library in catalog.libraries) {
      libraries.add(await _library(library));
    }
    final manifest = BackupManifest(libraries, missingOriginals: _missing);
    final encoded = manifest.encode();
    final bytes = utf8.encode(encoded);
    // Export must obey the same limits and mappings as restore. The manifest
    // already counts as one entry, but its bytes still count toward the budget.
    if (bytes.length > BackupArchive.maxManifestBytes ||
        _bytes + bytes.length > BackupArchive.maxExpandedBytes) {
      throw const AppFailure('Backup is too large.');
    }
    try {
      BackupManifest.decode(encoded);
    } on FormatException {
      throw const AppFailure('A source file could not be backed up.');
    }
    await File(p.join(stage, 'manifest.json')).writeAsBytes(bytes);
    return manifest;
  }

  Future<BackupLibrary> _library(StudyLibrary library) async {
    final id = const Uuid().v4();
    final entry = 'libraries/$id/database.sqlite';
    final target = File(p.join(stage, entry));
    await target.parent.create(recursive: true);
    final documents = await _snapshot(library, target.path);
    final snapshotBytes = await target.length();
    if (snapshotBytes > 128 * 1024 * 1024) {
      throw const AppFailure('Backup is too large.');
    }
    _account(snapshotBytes);
    final files = <BackupMaterial>[];
    final seen = <String>{};
    await for (final result in DirectoryLibraryFiles(
      library.directory,
    ).scan()) {
      final input = result.input;
      if (input == null) {
        throw const AppFailure('A source file could not be backed up.');
      }
      files.add(await _material(id, input.origin, input.name, input.bytes));
      seen.add(input.origin);
    }
    await _legacyOriginals(id, documents, seen, files);
    return BackupLibrary(name: library.name, database: entry, files: files);
  }

  Future<List<StudyDocument>> _snapshot(
    StudyLibrary library,
    String target,
  ) async {
    final shared = library.legacy || library.id == activeId;
    final db = library.legacy
        ? catalog.database
        : library.id == activeId
        ? activeDatabase!
        : QuizDatabase(
            NativeDatabase.createInBackground(
              File(catalog.databasePath(library)),
            ),
          );
    try {
      final documents = await SqlMaterialRepository(db).documents();
      await BackupDatabase.snapshot(db, target);
      return documents;
    } finally {
      if (!shared) await db.close();
    }
  }

  Future<BackupMaterial> _material(
    String id,
    String origin,
    String relative,
    List<int> bytes,
  ) async {
    _account(bytes.length);
    final entry = 'libraries/$id/files/${const Uuid().v4()}';
    final target = File(p.join(stage, entry));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes);
    return BackupMaterial(
      entry: entry,
      path: relative.replaceAll('\\', '/'),
      origin: origin,
    );
  }

  Future<void> _legacyOriginals(
    String id,
    List<StudyDocument> documents,
    Set<String> seen,
    List<BackupMaterial> files,
  ) async {
    for (final document in documents) {
      if (seen.contains(document.origin)) continue;
      final source = File(document.origin);
      if (await FileSystemEntity.type(source.path, followLinks: false) ==
              FileSystemEntityType.file &&
          await source.length() <= 20 * 1024 * 1024) {
        files.add(
          await _material(
            id,
            document.origin,
            'Imported/${document.id}/${p.basename(document.name)}',
            await source.readAsBytes(),
          ),
        );
      } else {
        // Old imported text may outlive its original file. Keep its DB snapshot
        // and report this count instead of silently claiming a full source copy.
        _missing++;
      }
    }
  }

  void _account(int bytes) {
    _bytes += bytes;
    _entries++;
    if (_bytes > BackupArchive.maxExpandedBytes ||
        _entries > BackupArchive.maxEntries) {
      throw const AppFailure('Backup is too large.');
    }
  }
}
