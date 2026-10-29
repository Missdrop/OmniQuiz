// Keeps portable study state next to materials, without following metadata links.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models.dart';
import '../platform/folder_permissions.dart';

/// The library directory is user-owned; only .omniquiz is managed by the app.
class LibraryWorkspace {
  LibraryWorkspace(this.directory);
  final String directory;
  String get metadata => p.join(directory, '.omniquiz');
  String get databasePath => p.join(metadata, 'quiz.sqlite');
  String get guidancePath => p.join(metadata, 'guidance');

  /// Restore access without creating new metadata during deletion.
  Future<void> ensureForDeletion() => FolderPermissions.restore(directory);

  /// Refuse links instead of redirecting private state outside the chosen root.
  Future<void> ensure() async {
    await FolderPermissions.restore(directory);
    if (!await Directory(directory).exists()) {
      throw const AppFailure(
        'Library folder is unavailable. Reconnect it and scan again.',
      );
    }
    await ensureDirectory(metadata);
    await requireRegularFile(databasePath);
  }

  static Future<void> ensureDirectory(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await Directory(path).create();
    } else if (type != FileSystemEntityType.directory) {
      throw const AppFailure('Library metadata contains an unsafe path.');
    }
  }

  static Future<void> requireRegularFile(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const AppFailure('Library metadata contains an unsafe path.');
    }
  }
}
