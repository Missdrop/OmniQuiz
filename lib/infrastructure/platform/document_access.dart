// Reads user-selected materials with explicit size and format bounds before parsing.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';

/// Reads selected files into bounded import inputs using native picker permissions.
class PlatformDocumentAccess implements DocumentAccess {
  static const extensions = ['txt', 'md', 'markdown', 'pdf'];
  static const maxBytes = 20 * 1024 * 1024;
  @override
  bool get supportsDirectories =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  Future<ImportInput> _read(String path, {String? name}) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw AppFailure(
        '${name ?? p.basename(path)} exceeds the 20 MB file limit.',
      );
    }
    return ImportInput(
      name: name ?? p.basename(path),
      origin: p.normalize(p.absolute(path)),
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<List<ImportInput>> pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    final result = <ImportInput>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) {
        throw const AppFailure(
          'The selected file could not be read. Try copying it to this device first.',
        );
      }
      result.add(await _read(path, name: file.name));
    }
    return result;
  }

  @override
  Future<List<ImportInput>> pickDirectory() async {
    if (!supportsDirectories) {
      throw const AppFailure('Use Import files on this device.');
    }
    final directory = await FilePicker.getDirectoryPath();
    if (directory == null) return [];
    final result = <ImportInput>[];
    var bytes = 0;
    await for (final entry in Directory(
      directory,
    ).list(recursive: true, followLinks: false)) {
      if (entry is! File ||
          !extensions.contains(
            p.extension(entry.path).replaceFirst('.', '').toLowerCase(),
          )) {
        continue;
      }
      if (p
          .split(p.relative(entry.path, from: directory))
          .any((part) => part.startsWith('.'))) {
        continue;
      }
      final input = await _read(entry.path);
      bytes += input.bytes.length;
      if (result.length >= 100 || bytes > 100 * 1024 * 1024) {
        throw const AppFailure(
          'Import at most 100 files / 100 MB at once. Select a smaller folder.',
        );
      }
      result.add(input);
    }
    return result;
  }
}
