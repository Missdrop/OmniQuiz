import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../application/ports/backup.dart';
import '../../domain/models.dart';

/// SaveFile writes the bytes through the platform API, including mobile SAF /
/// document providers. Do not assume its returned URI is a filesystem path.
class PlatformBackupActions implements BackupActions {
  PlatformBackupActions(this.backups);
  final BackupPort backups;

  @override
  Future<int?> export() async {
    final directory = await Directory.systemTemp.createTemp('omniquiz-export-');
    try {
      final file = File(p.join(directory.path, 'OmniQuiz-backup.zip'));
      final missing = await backups.exportTo(file.path);
      final saved = await FilePicker.saveFile(
        fileName: 'OmniQuiz-backup.zip',
        mimeType: 'application/zip',
        bytes: await file.readAsBytes(),
      );
      return saved == null ? null : missing;
    } finally {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<int?> restore() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (file == null) return null;
    if (file.path == null) throw const AppFailure('Backup could not be read.');
    return backups.restoreFrom(file.path!);
  }
}
