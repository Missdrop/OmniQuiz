// Real filesystem coverage for portable databases, editable guidance and complete backups.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/domain/generation_guidance.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/domain/study_library.dart';
import 'package:omniquiz/infrastructure/backup/library_backup.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:omniquiz/infrastructure/persistence/library_workspace.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'generation_guidance_test.dart' show SamplePicker, GuidanceGenerator;
import 'support/folder_permissions.dart';

void main() {
  mockFolderPermissions();
  test(
    'old centralized databases migrate once without losing answers or feedback',
    () async {
      final root = await Directory.systemTemp.createTemp('omniquiz-old-store-');
      final global = QuizDatabase(NativeDatabase.memory());
      final catalog = LibraryCatalog(global, root.path);
      final materials = await Directory(p.join(root.path, 'course')).create();
      final library = StudyLibrary(
        id: 'old-course',
        name: 'Course',
        directory: materials.path,
      );
      final previous = File(catalog.legacyDatabasePath(library));
      await previous.parent.create(recursive: true);
      final old = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase(previous)),
        credentialStore: MemoryCredentials(),
        ai: GuidanceGenerator(),
      );
      await old.library.import(sample: true);
      await old.settings.save(
        'https://example.test/v1',
        'model',
        'key',
        false,
        'English',
        false,
      );
      await old.practice.startPractice();
      await old.practice.refresh();
      await old.practice.answer('b');
      final question = old.practice.current!.id;
      await old.practice.rate(QuestionRating.bad);
      await old.dispose();
      final migrated = await catalog.openLibrary(library);
      try {
        expect(
          (await migrated
                  .customSelect('SELECT COUNT(*) n FROM attempts')
                  .getSingle())
              .read<int>('n'),
          1,
        );
        final vote = await migrated
            .customSelect('SELECT question_id,rating FROM feedback')
            .getSingle();
        expect(vote.read<String>('question_id'), question);
        expect(vote.read<String>('rating'), 'bad');
        expect(
          await previous.exists(),
          isTrue,
          reason: 'Retain migration recovery, but use only the portable DB afterwards',
        );
        expect(
          await migrated
              .customSelect("SELECT value FROM settings WHERE key='profile'")
              .getSingleOrNull(),
          isNull,
        );
      } finally {
        await migrated.close();
        await global.close();
        await root.delete(recursive: true);
      }
    },
  );
  test('moving a complete folder rebases original paths without duplicating questions or history', () async {
    final root = await Directory.systemTemp.createTemp('omniquiz-move-');
    final global = QuizDatabase(NativeDatabase.memory());
    final catalog = LibraryCatalog(global, root.path);
    final first = await catalog.create('First');
    final deps = await AppDependencies.create(
      database: await catalog.openLibrary(first),
      settingsDatabase: global,
      libraryFiles: DirectoryLibraryFiles(first.directory),
      credentialStore: MemoryCredentials(),
      ai: GuidanceGenerator(),
    );
    await deps.library.import(sample: true);
    final id = deps.library.documents.single.id;
    await deps.settings.save(
      'https://example.test/v1',
      'model',
      'key',
      false,
      'English',
      false,
    );
    await deps.practice.startPractice();
    await deps.practice.refresh();
    await deps.practice.answer('b');
    await deps.dispose();
    final moved = await Directory(first.directory)
        .rename(p.join(root.path, 'moved-course'));
    final attached = await catalog.create('Moved', directory: moved.path);
    final reopened = await AppDependencies.create(
      database: await catalog.openLibrary(attached),
      settingsDatabase: global,
      libraryFiles: DirectoryLibraryFiles(attached.directory),
      credentialStore: MemoryCredentials(),
      ai: GuidanceGenerator(),
    );
    try {
      await reopened.library.scan();
      expect(reopened.library.documents, hasLength(1));
      final document = reopened.library.documents.single;
      expect(document.id, id);
      expect(p.isWithin(attached.directory, document.origin), isTrue);
      expect(await File(document.origin).exists(), isTrue);
      expect((await reopened.practice.questions.stats()).attempts, 1);
      expect(await reopened.practice.questions.reviews(), hasLength(1));
    } finally {
      await reopened.dispose();
      await global.close();
      await root.delete(recursive: true);
    }
  });
  test('portable state survives reopen, external edits, feedback and a complete backup restore', () async {
    final root = await Directory.systemTemp.createTemp('omniquiz-portable-');
    final global = QuizDatabase(NativeDatabase.memory());
    final catalog = LibraryCatalog(global, root.path);
    await catalog.load();
    final library = await catalog.create('Course');
    final picker = SamplePicker()
      ..inputs = [
        ImportInput(
          name: 'exam.md',
          origin: 'selected',
          bytes: utf8.encode('Compare two scenarios.'),
        ),
      ];
    final ai = GuidanceGenerator();
    final deps = await AppDependencies.create(
      database: await catalog.openLibrary(library),
      settingsDatabase: global,
      libraryFiles: DirectoryLibraryFiles(library.directory),
      documentAccess: picker,
      credentialStore: MemoryCredentials(),
      ai: ai,
    );
    try {
      expect(
        catalog.databasePath(library),
        p.join(library.directory, '.omniquiz', 'quiz.sqlite'),
      );
      await deps.library.import(sample: true);
      await deps.settings.save(
        'https://example.test/v1',
        'model',
        'key',
        false,
        'English',
        false,
      );
      final examples = await deps.guidance.importExamples([]);
      expect(
        await deps.guidance.save(
          GenerationGuidance(
            requirements: 'Application questions.',
            examples: examples,
          ),
        ),
        isTrue,
      );
      final folder = LibraryWorkspace(library.directory).guidancePath;
      final original = File(p.join(folder, 'examples', 'exam.md'));
      expect(await original.readAsString(), 'Compare two scenarios.');
      await File(p.join(folder, 'requirements.md'))
          .writeAsString('Short explanations.');
      await deps.practice.startPractice();
      await deps.practice.refresh();
      expect(ai.requests.first.additionalRequirements, 'Short explanations.');
      final question = deps.practice.current!;
      await Future.wait([deps.practice.answer('b'), deps.practice.answer('a')]);
      expect((await deps.practice.questions.stats()).attempts, 1);
      await deps.practice.rate(QuestionRating.good);
      expect(
        await deps.practice.questions.feedback(question.id),
        QuestionRating.good,
      );
      await deps.practice.endPractice();
      final backup = p.join(root.path, 'backup.zip');
      final port = LibraryBackup(
        catalog,
        activeDatabase: deps.database,
        activeId: library.id,
      );
      expect(await port.exportTo(backup), 0);
      expect(await port.restoreFrom(backup), 1);
      final restored = catalog.libraries.last;
      expect(
        await File(
          p.join(
            LibraryWorkspace(restored.directory).guidancePath,
            'examples',
            'exam.md',
          ),
        ).readAsString(),
        'Compare two scenarios.',
      );
      final db = await catalog.openLibrary(restored);
      expect(
        (await db.customSelect('SELECT COUNT(*) n FROM attempts').getSingle())
            .read<int>('n'),
        1,
      );
      expect(
        (await db.customSelect('SELECT rating FROM feedback').getSingle())
            .read<String>('rating'),
        'good',
      );
      await db.close();
      await deps.guidance.load();
      expect(
        await deps.guidance.save(
          GenerationGuidance(
            requirements: 'Another change.',
            examples: deps.guidance.value.examples,
          ),
        ),
        isTrue,
      );
      expect(
        await original.readAsString(),
        'Compare two scenarios.',
        reason: 'Editing requirements retains original sample bytes',
      );
      final log = File(
        p.join(library.directory, '.omniquiz', 'generation.log'),
      );
      await deps.generationLog!.flush();
      expect(await log.readAsString(), contains('Reading sample papers'));
      expect(await log.readAsString(), isNot(contains('Short explanations.')));
      await deps.practice.rate(
        QuestionRating.error,
        note: 'Incorrect answer key.',
      );
      expect(
        await deps.practice.questions.feedback(question.id),
        QuestionRating.error,
      );
      expect((await deps.practice.questions.stats()).attempts, 1);
      expect(
        (await deps.database
                .customSelect('SELECT COUNT(*) n FROM reviews')
                .getSingle())
            .read<int>('n'),
        1,
      );
      expect(await deps.practice.questions.reviews(), isEmpty);
    } finally {
      await deps.dispose();
      await global.close();
      await root.delete(recursive: true);
    }
  });
}
