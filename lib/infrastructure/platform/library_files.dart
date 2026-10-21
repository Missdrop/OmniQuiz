import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../application/libraries/library_files.dart';
import '../../application/libraries/scan_state.dart';
import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import 'document_access.dart';
import 'folder_permissions.dart';

class DirectoryLibraryFiles implements LibraryFiles {
  DirectoryLibraryFiles(this.directory);
  @override
  final String directory;

  @override
  bool containsOrigin(String origin) =>
      p.isWithin(p.normalize(p.absolute(directory)), origin);

  @override
  Stream<LibraryScanEntry> scan({
    bool Function(FileStamp)? skip,
    bool Function()? cancelled,
  }) async* {
    await FolderPermissions.restore(directory);
    // Never recreate a missing external volume or follow links outside the root.
    if (!await Directory(directory).exists()) {
      throw const AppFailure(
        'Library folder is unavailable. Reconnect it and scan again.',
      );
    }
    await for (final entry in _files(Directory(directory), cancelled)) {
      if (cancelled?.call() == true) return;
      final relative = p.relative(entry.path, from: directory);
      if (p.split(relative).any((part) => part.startsWith('.'))) continue;
      if (!PlatformDocumentAccess.extensions.contains(
        p.extension(entry.path).replaceFirst('.', '').toLowerCase(),
      )) {
        continue;
      }
      FileStamp? stamp;
      try {
        final stat = await entry.stat();
        stamp = FileStamp(
          p.normalize(p.absolute(entry.path)),
          relative,
          stat.size,
          stat.modified.microsecondsSinceEpoch,
        );
        if (skip?.call(stamp) == true) {
          yield LibraryScanEntry.skipped(stamp);
          continue;
        }
        if (stat.size > PlatformDocumentAccess.maxBytes) {
          yield LibraryScanEntry.failed(
            '$relative: File exceeds 20 MB.',
            stamp: stamp,
          );
          continue;
        }
        yield LibraryScanEntry.read(
          ImportInput(
            name: relative,
            origin: p.normalize(p.absolute(entry.path)),
            bytes: await entry.readAsBytes(),
          ),
          // If a file changed while reading it, discard the hint so the next
          // scan reads it again instead of trusting mixed metadata/content.
          stamp:
              await entry.lastModified() == stat.modified &&
                  await entry.length() == stat.size
              ? stamp
              : null,
        );
      } catch (_) {
        yield LibraryScanEntry.failed(
          '$relative: Could not read this file.',
          stamp: stamp,
        );
      }
    }
  }

  Stream<File> _files(Directory folder, bool Function()? cancelled) async* {
    await for (final entry in folder.list(followLinks: false)) {
      if (cancelled?.call() == true) return;
      if (p.basename(entry.path).startsWith('.')) continue;
      if (entry is File) yield entry;
      if (entry is Directory) yield* _files(entry, cancelled);
    }
  }

  @override
  Future<ImportInput> store(
    ImportInput input, {
    bool preserveDirectories = false,
  }) async {
    if (input.bytes.length > PlatformDocumentAccess.maxBytes) {
      throw const AppFailure('File exceeds 20 MB.');
    }
    await FolderPermissions.restore(directory);
    final root = Directory(directory);
    if (!await root.exists()) {
      throw const AppFailure(
        'Library folder is unavailable. Reconnect it and scan again.',
      );
    }
    final name = preserveDirectories
        ? input.name.replaceAll('\\', '/')
        : p.basename(input.name);
    final parts = name.split('/');
    if (p.posix.isAbsolute(name) ||
        p.windows.isAbsolute(name) ||
        parts.any(
          (part) =>
              part.isEmpty || part == '.' || part == '..' || part.contains(':'),
        )) {
      throw const AppFailure('Cannot copy this file into the library folder.');
    }
    var parent = directory;
    // Existing links inside a selected directory must not redirect an import.
    for (final part in parts.take(parts.length - 1)) {
      parent = p.join(parent, part);
      final type = await FileSystemEntity.type(parent, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        await Directory(parent).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const AppFailure(
          'Cannot copy this file into the library folder.',
        );
      }
    }
    final filename = parts.last;
    var target = File(p.join(parent, filename));
    // Do not overwrite a user's different file with a matching name.
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final digest = sha256.convert(input.bytes).toString();
      if (await FileSystemEntity.type(target.path, followLinks: false) ==
              FileSystemEntityType.file &&
          await target.length() == input.bytes.length &&
          sha256.convert(await target.readAsBytes()).toString() == digest) {
        return ImportInput(
          name: name,
          origin: p.normalize(p.absolute(target.path)),
          bytes: input.bytes,
        );
      }
      target = File(
        p.join(
          parent,
          '${p.basenameWithoutExtension(filename)}-$digest${p.extension(filename)}',
        ),
      );
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        if (await FileSystemEntity.type(target.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await target.length() != input.bytes.length ||
            sha256.convert(await target.readAsBytes()).toString() != digest) {
          throw const AppFailure(
            'Cannot copy this file into the library folder.',
          );
        }
      }
    }
    await target.writeAsBytes(input.bytes, flush: true);
    return ImportInput(
      name: p.relative(target.path, from: directory),
      origin: p.normalize(p.absolute(target.path)),
      bytes: input.bytes,
    );
  }
}
