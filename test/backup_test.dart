import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/backup/backup_archive.dart';
import 'package:omniquiz/infrastructure/backup/library_backup.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  late Directory root;
  late QuizDatabase global;
  late LibraryCatalog catalog;
  late AppDependencies deps;
  final warning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = warning,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('omniquiz-backup-test-');
    global = QuizDatabase(
      NativeDatabase(File(p.join(root.path, 'omniquiz.sqlite'))),
    );
    catalog = LibraryCatalog(global, root.path);
    await catalog.load();
    deps = await AppDependencies.create(
      database: global,
      ownsDatabase: false,
      libraryFiles: DirectoryLibraryFiles(catalog.selected.directory),
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    await deps.library.import(sample: true);
    await deps.settings.save(
      'https://example.com/v1',
      'model',
      'SECRET-DO-NOT-EXPORT',
      false,
      'English',
      false,
    );
    await deps.coordinator.start(null);
    await deps.practice.refresh();
    deps.practice.choose('b');
    await deps.practice.submit();
    await deps.coordinator.quiesce();
  });
  tearDown(() async {
    await deps.dispose();
    await global.close();
    await root.delete(recursive: true);
  });

  test('portable backup restores libraries, sources, questions and wrong answers without overwriting originals or AI settings', () async {
    await catalog.create('Second library');
    final service = LibraryBackup(catalog);
    final archive = p.join(root.path, 'backup.zip');
    expect(await service.exportTo(archive), 0);
    expect(await service.restoreFrom(archive), 2);
    expect(catalog.libraries, hasLength(4));
    expect(catalog.selectedId, 'default');
    expect((await SqlQuestionRepository(global).stats()).attempts, 1);
    expect((await SqlProfileRepository(global).load())?.model, 'model');
    final restored = catalog.libraries[2];
    final database = QuizDatabase(
      NativeDatabase(File(catalog.databasePath(restored))),
    );
    try {
      final questions = SqlQuestionRepository(database);
      expect((await questions.stats()).attempts, 1);
      expect(await questions.reviews(), hasLength(1));
      final document = (await SqlMaterialRepository(
        database,
      ).documents()).single;
      expect(p.isWithin(restored.directory, document.origin), true);
      expect(await File(document.origin).exists(), true);
      expect(await SqlProfileRepository(database).load(), isNull);
    } finally {
      await database.close();
    }
    // A new installation's catalog can read the same restored metadata.
    final reload = LibraryCatalog(global, root.path);
    await reload.load();
    expect(reload.libraries.length, 4);
  });

  test(
    'backup omits API profile and credentials even from SQLite freelist pages',
    () async {
      await deps.library.scan();
      final archive = p.join(root.path, 'backup.zip');
      await LibraryBackup(catalog).exportTo(archive);
      final stage = await Directory(p.join(root.path, 'unpacked')).create();
      final manifest = BackupArchive.unpack(archive, stage.path);
      final file = File(p.join(stage.path, manifest.libraries.single.database));
      final db = sqlite.sqlite3.open(file.path);
      try {
        expect(db.select('SELECT key FROM settings').map((r) => r['key']), [
          'epoch',
          'library_scan',
        ]);
        expect(
          db.select(
            "SELECT * FROM jobs WHERE state IN ('queued','running','retryScheduled')",
          ),
          isEmpty,
        );
      } finally {
        db.close();
      }
      final raw = latin1.decode(await file.readAsBytes());
      expect(raw, isNot(contains('https://example.com/v1')));
      expect(raw, isNot(contains('SECRET-DO-NOT-EXPORT')));
    },
  );

  test('damaged archives and hostile manifests leave catalog and existing learning records unchanged', () async {
    final file = File(p.join(root.path, 'invalid.zip'));
    await file.writeAsBytes(
      ZipEncoder().encode(
        Archive()..add(ArchiveFile.string('../escape.sqlite', 'unsafe')),
      ),
    );
    final service = LibraryBackup(catalog);
    await expectLater(
      service.restoreFrom(file.path),
      throwsA(isA<AppFailure>()),
    );
    expect(catalog.libraries.length, 1);
    expect((await SqlQuestionRepository(global).stats()).attempts, 1);
    expect(await File(p.join(root.path, 'escape.sqlite')).exists(), false);
    await file.writeAsString('truncated');
    await expectLater(
      service.restoreFrom(file.path),
      throwsA(isA<AppFailure>()),
    );
    expect(catalog.libraries.length, 1);
  });

  test('missing legacy originals retain cached text and progress in a restored library', () async {
    final doc = deps.library.documents.single;
    await File(doc.origin).delete();
    final archive = p.join(root.path, 'missing.zip');
    final service = LibraryBackup(catalog);
    expect(await service.exportTo(archive), 1);
    await service.restoreFrom(archive);
    final restored = catalog.libraries.last;
    final db = QuizDatabase(
      NativeDatabase(File(catalog.databasePath(restored))),
    );
    try {
      expect(
        (await SqlMaterialRepository(db).documents()).single.origin,
        startsWith('restored:'),
      );
      expect(await SqlMaterialRepository(db).chunks(null), isNotEmpty);
      expect((await SqlQuestionRepository(db).stats()).attempts, 1);
    } finally {
      await db.close();
    }
  });
  test(
    'backup preserves exclusions and rebases them to the restored folder',
    () async {
      await deps.library.refresh();
      await deps.library.remove(deps.library.documents.single.id);
      final service = LibraryBackup(catalog);
      final archive = p.join(root.path, 'excluded.zip');
      await service.exportTo(archive);
      await service.restoreFrom(archive);
      final restored = catalog.libraries.last;
      final copy = await AppDependencies.create(
        database: QuizDatabase(
          NativeDatabase(File(catalog.databasePath(restored))),
        ),
        settingsDatabase: global,
        libraryFiles: DirectoryLibraryFiles(restored.directory),
        credentialStore: MemoryCredentials(),
        ai: FakeGenerator(),
      );
      try {
        await copy.library.scan();
        expect(copy.library.documents, isEmpty);
        expect(copy.library.excluded, hasLength(1));
        final origin = copy.library.excluded.keys.single;
        expect(p.isWithin(restored.directory, origin), true);
        await copy.library.include(origin);
        expect(copy.library.documents, hasLength(1));
      } finally {
        await copy.dispose();
      }
    },
  );
}
