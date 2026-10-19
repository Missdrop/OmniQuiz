import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../application/libraries/library_files.dart';
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
  Stream<LibraryScanEntry> scan() async* {
    await FolderPermissions.restore(directory);
    // Never recreate a missing external volume or follow links outside the root.
    if (!await Directory(directory).exists()) {
      throw const AppFailure(
        'Library folder is unavailable. Reconnect it and scan again.',
      );
    }
    await for (final entry in _files(Directory(directory))) {
      final relative = p.relative(entry.path, from: directory);
      if (p.split(relative).any((part) => part.startsWith('.'))) continue;
      if (!PlatformDocumentAccess.extensions.contains(
        p.extension(entry.path).replaceFirst('.', '').toLowerCase(),
      )) {
        continue;
      }
      try {
        if (await entry.length() > PlatformDocumentAccess.maxBytes) {
          yield LibraryScanEntry.failed('$relative: File exceeds 20 MB.');
          continue;
        }
        yield LibraryScanEntry.read(
          ImportInput(
            name: relative,
            origin: p.normalize(p.absolute(entry.path)),
            bytes: await entry.readAsBytes(),
          ),
        );
      } catch (_) {
        yield LibraryScanEntry.failed('$relative: Could not read this file.');
      }
    }
  }

  Stream<File> _files(Directory folder) async* {
    await for (final entry in folder.list(followLinks: false)) {
      if (p.basename(entry.path).startsWith('.')) continue;
      if (entry is File) yield entry;
      if (entry is Directory) yield* _files(entry);
    }
  }

  @override
  Future<ImportInput> store(ImportInput input) async {
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
    final name = p.basename(input.name);
    var target = File(p.join(directory, name));
    // Do not overwrite a user's different file with a matching name.
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final digest = sha256.convert(input.bytes).toString();
      if (await FileSystemEntity.type(target.path, followLinks: false) ==
              FileSystemEntityType.file &&
          sha256.convert(await target.readAsBytes()).toString() == digest) {
        return ImportInput(
          name: name,
          origin: p.normalize(p.absolute(target.path)),
          bytes: input.bytes,
        );
      }
      target = File(
        p.join(
          directory,
          '${p.basenameWithoutExtension(name)}-$digest${p.extension(name)}',
        ),
      );
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        if (await FileSystemEntity.type(target.path, followLinks: false) !=
                FileSystemEntityType.file ||
            sha256.convert(await target.readAsBytes()).toString() != digest) {
          throw const AppFailure(
            'Cannot copy this file into the library folder.',
          );
        }
      }
    }
    await target.writeAsBytes(input.bytes, flush: true);
    return ImportInput(
      name: p.basename(target.path),
      origin: p.normalize(p.absolute(target.path)),
      bytes: input.bytes,
    );
  }
}
