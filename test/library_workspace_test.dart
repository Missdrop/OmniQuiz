import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';
import 'package:path/path.dart' as p;

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  // Each library deliberately has its own file and executor.
  final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning,
  );
  late Directory root;
  late QuizDatabase global;
  late LibraryCatalog catalog;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('omniquiz-libraries-');
    global = QuizDatabase(
      NativeDatabase(File(p.join(root.path, 'omniquiz.sqlite'))),
    );
    catalog = LibraryCatalog(global, root.path);
    await catalog.load();
  });
  tearDown(() async {
    await global.close();
    await root.delete(recursive: true);
  });

  test('legacy data remains in default; catalog persists selection and rejects overlapping folders', () async {
    final deps = await AppDependencies.create(
      database: global,
      ownsDatabase: false,
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    await deps.library.import(sample: true);
    final defaultDocument = deps.library.documents.single;
    final external = await Directory(p.join(root.path, 'external')).create();
    final nested = await Directory(p.join(external.path, 'nested')).create();
    final item = await catalog.create('External', directory: external.path);
    await expectLater(
      catalog.create('Duplicate', directory: external.path),
      throwsFormatException,
    );
    await expectLater(
      catalog.create('Child', directory: nested.path),
      throwsFormatException,
    );
    await expectLater(
      catalog.create('Parent', directory: root.path),
      throwsFormatException,
    );
    await catalog.select(item);
    final reloaded = LibraryCatalog(global, root.path);
    await reloaded.load();
    expect(reloaded.selected.id, item.id);
    expect(
      reloaded.databasePath(reloaded.libraries.first),
      p.join(root.path, 'omniquiz.sqlite'),
    );
    expect(
      (await SqlMaterialRepository(global).documents()).single.id,
      defaultDocument.id,
    );
    await deps.dispose();
  });

  test('independent questions, mistakes, attempts and jobs with shared provider and language', () async {
    final credentials = MemoryCredentials();
    final first = await AppDependencies.create(
      database: global,
      ownsDatabase: false,
      libraryFiles: DirectoryLibraryFiles(catalog.selected.directory),
      credentialStore: credentials,
      ai: FakeGenerator(),
    );
    await first.settings.save(
      'https://example.com/v1',
      'test-model',
      'key',
      false,
      'English',
      false,
    );
    await first.language.select('zh');
    await first.library.import(sample: true);
    await first.coordinator.start(null);
    await first.practice.refresh();
    first.practice.choose('b');
    await first.practice.submit();
    await first.coordinator.stop();
    await first.review.refresh();
    expect(first.review.entries, hasLength(1));

    final item = await catalog.create('Second');
    var second = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase(File(catalog.databasePath(item)))),
      settingsDatabase: global,
      libraryFiles: DirectoryLibraryFiles(item.directory),
      credentialStore: credentials,
      ai: FakeGenerator(),
    );
    expect(second.language.language, 'zh');
    await second.settings.load();
    expect(second.settings.profile?.model, 'test-model');
    await second.library.refresh();
    expect(second.library.stats.documents, 0);
    expect(second.library.stats.ready, 0);
    expect(second.library.stats.attempts, 0);
    expect(await second.review.questions.reviews(), isEmpty);
    await second.library.import(sample: true);
    await second.coordinator.start(null);
    expect(
      (await SqlQuestionRepository(second.database).ready(null)),
      hasLength(20),
    );
    expect((await SqlQuestionRepository(global).stats()).attempts, 1);
    expect(
      await second.database.customSelect('SELECT * FROM attempts').get(),
      isEmpty,
    );
    await second.dispose();

    // Reopening retains this library's question bank without touching default.
    second = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase(File(catalog.databasePath(item)))),
      settingsDatabase: global,
      credentialStore: credentials,
      ai: FakeGenerator(),
    );
    expect((await SqlQuestionRepository(second.database).stats()).ready, 20);
    expect((await SqlQuestionRepository(global).reviews()), hasLength(1));
    await second.dispose();
    await first.dispose();
  });

  test('recursively scans over 100 files, updates revisions, retains missing sources and retains cache on missing volume', () async {
    final item = await catalog.create('Directory');
    final directory = Directory(item.directory);
    await Directory(p.join(item.directory, 'chapter')).create();
    final note = File(p.join(item.directory, 'chapter', 'notes.md'));
    await note.writeAsString('Original notes.');
    for (var i = 0; i < 101; i++) {
      await File(p.join(item.directory, 'file-$i.txt'))
          .writeAsString('Text $i');
    }
    await Directory(p.join(item.directory, '.hidden')).create();
    await File(p.join(item.directory, '.hidden', 'secret.md'))
        .writeAsString('Skip');
    await File(p.join(item.directory, 'image.png')).writeAsString('Skip');
    await Link(p.join(item.directory, 'link.md')).create(note.path);
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      libraryFiles: DirectoryLibraryFiles(item.directory),
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    await deps.library.scan();
    expect(deps.library.documents, hasLength(102));
    final original = deps.library.documents.firstWhere(
      (d) => d.name.endsWith('notes.md'),
    );
    await deps.library.scan();
    expect(deps.library.message, contains('102 unchanged'));
    await note.writeAsString('Changed notes.');
    await deps.library.scan();
    final updated = deps.library.documents.firstWhere(
      (d) => d.id == original.id,
    );
    expect(updated.revision, isNot(original.revision));
    await note.delete();
    await deps.library.scan();
    expect(deps.library.documents, hasLength(102));
    expect(deps.library.missingOrigins, contains(original.origin));
    final moved = await directory.rename('${directory.path}-disconnected');
    await deps.library.scan();
    expect(deps.library.message, contains('Could not scan'));
    expect(deps.library.documents, hasLength(102));
    expect(await directory.exists(), false);
    await moved.rename(directory.path);
    await deps.dispose();
  });

  test(
    'copying files is idempotent and never overwrites a different file',
    () async {
      final files = DirectoryLibraryFiles(catalog.selected.directory);
      ImportInput input(String text) => ImportInput(
        name: 'notes.md',
        origin: 'upload',
        bytes: utf8.encode(text),
      );
      final first = await files.store(input('One'));
      expect((await files.store(input('One'))).origin, first.origin);
      final second = await files.store(input('Two'));
      expect(second.origin, isNot(first.origin));
      expect((await files.store(input('Two'))).origin, second.origin);
      expect(await File(first.origin).readAsString(), 'One');
      expect(await files.scan().toList(), hasLength(2));
    },
  );
}
