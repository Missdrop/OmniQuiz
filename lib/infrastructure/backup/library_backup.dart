import 'dart:io';
import 'dart:isolate';

import '../../domain/models.dart';
import '../../application/ports/backup.dart';
import '../persistence/database.dart';
import '../persistence/library_catalog.dart';
import 'backup_archive.dart';
import 'backup_collector.dart';
import 'backup_database.dart';
import 'backup_manifest.dart';
import 'backup_restore.dart';

/// Coordinates independent archive, snapshot and catalog collaborators.
/// It never closes the caller's live/global database handles.
class LibraryBackup implements BackupPort {
  LibraryBackup(this.catalog, {this.activeDatabase, this.activeId});
  final QuizDatabase? activeDatabase;
  final String? activeId;
  final LibraryCatalog catalog;

  @override
  Future<int> exportTo(String output) async {
    final stage = await Directory.systemTemp.createTemp('omniquiz-backup-');
    try {
      final manifest = await BackupCollector(
        catalog,
        stage.path,
        activeDatabase: activeDatabase,
        activeId: activeId,
      ).collect();
      final stagePath = stage.path;
      await Isolate.run(() => BackupArchive.pack(stagePath, output));
      if (await File(output).length() > BackupArchive.maxArchiveBytes) {
        await File(output).delete();
        throw const AppFailure('Backup is too large.');
      }
      return manifest.missingOriginals;
    } finally {
      await stage.delete(recursive: true);
    }
  }

  @override
  Future<int> restoreFrom(String input) async {
    if (await File(input).length() > BackupArchive.maxArchiveBytes) {
      throw const AppFailure('Backup is too large.');
    }
    final stage = await Directory.systemTemp.createTemp('omniquiz-restore-');
    try {
      final stagePath = stage.path;
      final manifest = await Isolate.run(
        () => _prepareRestore(input, stagePath),
      );
      return await BackupRestore(catalog, stage.path).apply(manifest);
    } catch (_) {
      throw const AppFailure(
        'Backup is invalid or could not be restored. Your existing libraries were kept.',
      );
    } finally {
      await stage.delete(recursive: true);
    }
  }

  static BackupManifest _prepareRestore(String input, String stage) {
    final manifest = BackupArchive.unpack(input, stage);
    // Every snapshot is checked before BackupRestore touches app storage.
    for (final record in manifest.libraries) {
      BackupDatabase.validate('$stage/${record.database}');
    }
    return manifest;
  }
}
