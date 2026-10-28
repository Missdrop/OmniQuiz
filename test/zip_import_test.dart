// Archive import rejects traversal/oversized entries and preserves safe subfolder identities.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';
import 'package:omniquiz/infrastructure/platform/zip_document_access.dart';
import 'package:path/path.dart' as p;

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;
import 'support/folder_permissions.dart';

class ChosenZip implements ArchiveAccess {
  ChosenZip(this.path);
  final String path;
  @override
  Stream<ImportInput> pickZip() => ZipDocumentAccess().read(path);
}

void main() {
  mockFolderPermissions();
  late Directory temporary, materials;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('omniquiz-zip-test-');
    materials = await Directory(p.join(temporary.path, 'library')).create();
  });
  tearDown(() => temporary.delete(recursive: true));

  Future<File> zip(List<ArchiveFile> entries) async {
    final archive = Archive();
    for (final entry in entries) {
      archive.add(entry);
    }
    return File(p.join(temporary.path, 'materials.zip'))
        .writeAsBytes(ZipEncoder().encode(archive));
  }

  test('ZIP imports nested materials only into the current library, deduplicates, and preserves originals on conflicts', () async {
    final file = await zip([
      ArchiveFile.string('chapter 1/notes.md', 'First chapter.'),
      ArchiveFile.string('chapter 2/notes.md', 'Second chapter.'),
      ArchiveFile.string('中文/复习.txt', '中文资料。'),
      ArchiveFile.string('image.png', 'not a material'),
      ArchiveFile.string('__MACOSX/._notes.md', 'metadata'),
      ArchiveFile.string('.hidden/notes.md', 'hidden'),
    ]);
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      libraryFiles: DirectoryLibraryFiles(materials.path),
      archiveAccess: ChosenZip(file.path),
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    addTearDown(deps.dispose);
    await deps.library.importZip();
    expect(deps.library.documents, hasLength(3));
    expect(deps.library.message, startsWith('3 imported'));
    expect(
      await File(p.join(materials.path, 'chapter 1', 'notes.md'))
          .readAsString(),
      'First chapter.',
    );
    expect(await File(p.join(materials.path, 'image.png')).exists(), false);
    await deps.library.importZip();
    expect(deps.library.documents, hasLength(3));
    expect(deps.library.message, contains('3 unchanged'));
    await File(p.join(materials.path, 'chapter 1', 'notes.md'))
        .writeAsString('User edits.');
    await deps.library.importZip();
    expect(deps.library.documents, hasLength(4));
    expect(
      await File(p.join(materials.path, 'chapter 1', 'notes.md'))
          .readAsString(),
      'User edits.',
    );
  });

  test('rejects path traversal, Windows paths and symlinks before yielding any material', () async {
    for (final entry in [
      ArchiveFile.string('../escape.md', 'bad'),
      ArchiveFile.string('folder/../../escape.md', 'bad'),
      ArchiveFile.string('C:\\escape.md', 'bad'),
      ArchiveFile.string('/absolute.md', 'bad'),
      ArchiveFile.string('link.md', '../escape.md')..mode = 0xa1ff,
    ]) {
      final file = await zip([ArchiveFile.string('valid.md', 'Valid'), entry]);
      final emitted = <ImportInput>[];
      await expectLater(
        ZipDocumentAccess().read(file.path).forEach(emitted.add),
        throwsA(isA<AppFailure>()),
      );
      expect(emitted, isEmpty);
    }
  });

  test(
    'rejects case-insensitive duplicate paths and archives without materials',
    () async {
      var file = await zip([
        ArchiveFile.string('Notes.md', 'A'),
        ArchiveFile.string('notes.md', 'B'),
      ]);
      await expectLater(
        ZipDocumentAccess().read(file.path).toList(),
        throwsA(isA<AppFailure>()),
      );
      file = await zip([ArchiveFile.string('photo.jpg', 'image')]);
      await expectLater(
        ZipDocumentAccess().read(file.path).toList(),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test(
    'rejects corrupt data and declared size limits before importing files',
    () async {
      final file = await zip([
        ArchiveFile.noCompress('notes.md', 8, utf8.encode('ORIGINAL')),
      ]);
      var bytes = await file.readAsBytes();
      final payload = bytes.indexOf(
        utf8.encode('ORIGINAL').first,
        30 + 'notes.md'.length,
      );
      bytes[payload] ^= 1;
      await file.writeAsBytes(bytes);
      await expectLater(
        ZipDocumentAccess().read(file.path).toList(),
        throwsA(isA<AppFailure>()),
      );

      await zip([ArchiveFile.string('notes.md', 'small')]);
      bytes = await file.readAsBytes();
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i <= bytes.length - 46; i++) {
        if (data.getUint32(i, Endian.little) == 0x02014b50) {
          data.setUint32(i + 24, 21 * 1024 * 1024, Endian.little);
        }
      }
      // Match the local size as well; never attempt to allocate/decode that entry.
      data.setUint32(22, 21 * 1024 * 1024, Endian.little);
      await file.writeAsBytes(bytes);
      await expectLater(
        ZipDocumentAccess().read(file.path).toList(),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('rejects excessive entry counts and leaves an existing library untouched on invalid ZIP', () async {
    final file = await zip([
      for (var i = 0; i <= 1000; i++) ArchiveFile.string('$i.md', 'text'),
    ]);
    await expectLater(
      ZipDocumentAccess().read(file.path).toList(),
      throwsA(isA<AppFailure>()),
    );
    await file.writeAsString('not a zip');
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      libraryFiles: DirectoryLibraryFiles(materials.path),
      archiveAccess: ChosenZip(file.path),
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    addTearDown(deps.dispose);
    await deps.library.import(sample: true);
    final old = deps.library.documents.single.id;
    await deps.library.importZip();
    expect(deps.library.documents.single.id, old);
    expect(deps.library.message, contains('ZIP'));
    expect(
      await materials
          .list()
          .where((entry) => !p.basename(entry.path).startsWith('.'))
          .length,
      1,
    );
  });

  test(
    'an existing symlink in the destination cannot redirect nested ZIP files',
    () async {
      final outside = await Directory(p.join(temporary.path, 'outside'))
          .create();
      await Link(p.join(materials.path, 'chapter')).create(outside.path);
      final destination = DirectoryLibraryFiles(materials.path);
      await expectLater(
        destination.store(
          ImportInput(
            name: 'chapter/notes.md',
            origin: 'zip',
            bytes: utf8.encode('Text'),
          ),
          preserveDirectories: true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(await outside.list().isEmpty, true);
    },
  );
}
