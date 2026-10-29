// Deletion is limited to the registered library and preserves originals by default.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:path/path.dart' as p;

import 'support/folder_permissions.dart';

void main() {
  mockFolderPermissions();
  late Directory root;
  late QuizDatabase db;
  late LibraryCatalog catalog;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('omniquiz-delete-test-');
    final app = await Directory(p.join(root.path, 'app')).create();
    db = QuizDatabase(NativeDatabase.memory());
    catalog = LibraryCatalog(db, app.path);
    await catalog.load();
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('default deletion keeps original files and the other library, including persisted selection', () async {
    final folder = await Directory(p.join(root.path, 'course')).create();
    final notes = await File(p.join(folder.path, 'notes.pdf'))
        .writeAsString('original material');
    final first = await catalog.create('First', directory: folder.path);
    final second = await catalog.create('Second');
    await catalog.select(first);
    final opened = await catalog.openLibrary(first);
    await opened.customStatement(
      "INSERT INTO settings VALUES ('test-history','saved')",
    );
    await opened.close();
    await catalog.remove(first);
    expect(await notes.readAsString(), 'original material');
    expect(await Directory(p.join(folder.path, '.omniquiz')).exists(), isFalse);
    expect(await Directory(second.directory).exists(), isTrue);
    await catalog.load();
    expect(catalog.libraries.single.id, second.id);
    expect(catalog.selectedId, second.id);
  });

  test('explicit whole-folder deletion removes only that folder and supports deleting the last library', () async {
    final folder = await Directory(p.join(root.path, 'course')).create();
    await File(p.join(folder.path, 'notes.pdf')).writeAsString('material');
    final outside = await File(p.join(root.path, 'unrelated.txt'))
        .writeAsString('keep');
    final library = await catalog.create('Course', directory: folder.path);
    await catalog.select(library);
    await catalog.remove(library, keepMaterials: false);
    expect(await folder.exists(), isFalse);
    expect(await outside.readAsString(), 'keep');
    await catalog.load();
    expect(catalog.libraries, isEmpty);
    expect(catalog.selectedId, isEmpty);
  });

  test('an unavailable folder can be removed without recreating it', () async {
    final library = await catalog.create('Missing');
    await catalog.select(library);
    await Directory(library.directory).delete(recursive: true);
    await catalog.remove(library);
    expect(catalog.libraries, isEmpty);
    expect(await Directory(library.directory).exists(), isFalse);
  });

  test(
    'a folder containing global settings cannot be deleted as a whole',
    () async {
      final library = await catalog.create('Unsafe root', directory: root.path);
      await expectLater(
        catalog.remove(library, keepMaterials: false),
        throwsA(isA<AppFailure>()),
      );
      expect(await Directory(catalog.root).exists(), isTrue);
      expect(catalog.libraries.single.id, library.id);
    },
  );

  test('a failed catalog write restores staged learning data', () async {
    final library = await catalog.create('Rollback');
    final marker = await File(
      p.join(library.directory, '.omniquiz', 'history.txt'),
    ).writeAsString('saved');
    await db.close();
    await expectLater(catalog.remove(library), throwsA(anything));
    expect(await marker.readAsString(), 'saved');
    expect(catalog.libraries.single.id, library.id);
  });
  test('metadata links cannot redirect deletion into another folder', () async {
    final library = await catalog.create('Linked');
    final outside = await Directory(p.join(root.path, 'outside')).create();
    final marker = await File(p.join(outside.path, 'keep.txt'))
        .writeAsString('keep');
    final metadata = Directory(p.join(library.directory, '.omniquiz'));
    await metadata.delete(recursive: true);
    await Link(metadata.path).create(outside.path);
    try {
      await expectLater(catalog.remove(library), throwsA(isA<AppFailure>()));
      expect(await marker.readAsString(), 'keep');
      expect(catalog.libraries.single.id, library.id);
    } finally {
      await Link(metadata.path).delete();
    }
  });
  test(
    'private-storage path aliases resolve to the same registered library',
    () async {
      final alias = Link(p.join(root.path, 'private-alias'));
      await alias.create(catalog.root);
      try {
        final aliased = LibraryCatalog(db, alias.path);
        final library = await aliased.create('Alias');
        final notes = await File(p.join(library.directory, 'notes.txt'))
            .writeAsString('keep');
        await aliased.select(library);
        await aliased.remove(library);
        expect(await notes.readAsString(), 'keep');
        expect(aliased.libraries, isEmpty);
      } finally {
        await alias.delete();
      }
    },
  );
}
