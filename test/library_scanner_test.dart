import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/application/libraries/library_files.dart';
import 'package:omniquiz/application/libraries/library_scanner.dart';
import 'package:omniquiz/application/libraries/scan_state.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';
import 'package:path/path.dart' as p;

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;
import 'support/folder_permissions.dart';

class CountingFiles extends DirectoryLibraryFiles {
  CountingFiles(super.directory);
  int reads = 0;
  @override
  Stream<LibraryScanEntry> scan({
    bool Function(FileStamp)? skip,
    bool Function()? cancelled,
  }) async* {
    await for (final entry in super.scan(skip: skip, cancelled: cancelled)) {
      if (entry.input != null) reads++;
      yield entry;
    }
  }
}

void main() {
  mockFolderPermissions();
  late Directory folder;
  late QuizDatabase db;
  late CountingFiles files;
  late AppDependencies deps;
  Future<AppDependencies> open() => AppDependencies.create(
    database: db,
    ownsDatabase: false,
    libraryFiles: files,
    credentialStore: MemoryCredentials(),
    ai: FakeGenerator(),
  );
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('omniquiz-scan-');
    db = QuizDatabase(NativeDatabase.memory());
    files = CountingFiles(folder.path);
    deps = await open();
  });
  tearDown(() async {
    await deps.dispose();
    await db.close();
    await folder.delete(recursive: true);
  });

  test(
    'incremental hints survive reopen; full scan detects preserved metadata',
    () async {
      final file = File(p.join(folder.path, 'notes.md'));
      await file.writeAsString('First text');
      await deps.library.scan();
      final original = deps.library.documents.single;
      expect(files.reads, 1);
      await deps.dispose();
      deps = await open();
      await deps.library.scan();
      expect(files.reads, 1, reason: 'unchanged files must not be read again');
      final timestamp = await file.lastModified();
      await file.writeAsString('Other text');
      await file.setLastModified(timestamp);
      await deps.library.scan();
      expect(files.reads, 1);
      await deps.library.scan(full: true);
      expect(files.reads, 2);
      expect(deps.library.documents.single.id, original.id);
      expect(deps.library.documents.single.revision, isNot(original.revision));
    },
  );

  test(
    'excluded files stay excluded after reopen and can be explicitly restored',
    () async {
      final file = File(p.join(folder.path, 'notes.md'));
      await file.writeAsString('Study notes');
      await deps.library.scan();
      await deps.library.remove(deps.library.documents.single.id);
      expect(await file.readAsString(), 'Study notes');
      await deps.dispose();
      deps = await open();
      await deps.library.scan(full: true);
      expect(deps.library.documents, isEmpty);
      expect(deps.library.excluded.keys, contains(file.path));
      expect(files.reads, 1);
      await deps.library.include(file.path);
      expect(deps.library.documents, hasLength(1));
      expect(deps.library.excluded, isEmpty);
    },
  );

  test(
    'missing source preserves questions, wrong answers and extracted content',
    () async {
      final file = File(p.join(folder.path, 'notes.md'));
      await file.writeAsString('A useful source for a question.');
      await deps.library.scan();
      await deps.settings.save(
        'https://example.com/v1',
        'test',
        'key',
        false,
        'English',
        false,
      );
      await deps.coordinator.start(null);
      await deps.practice.refresh();
      deps.practice.choose('b');
      await deps.practice.submit();
      await deps.coordinator.stop();
      final before = await deps.library.questions.stats();
      await file.delete();
      await deps.library.scan();
      final after = await deps.library.questions.stats();
      expect(after.ready, before.ready);
      expect(after.attempts, before.attempts);
      expect(after.review, before.review);
      expect(deps.library.documents, hasLength(1));
      expect(deps.library.missingOrigins, contains(file.path));
      expect(
        await deps.library.source(deps.library.documents.single.id),
        isNotEmpty,
      );
    },
  );

  test(
    'cancellation keeps completed imports and the next scan resumes safely',
    () async {
      for (var i = 0; i < 5; i++) {
        await File(p.join(folder.path, '$i.md')).writeAsString('Text $i');
      }
      final token = ScanCancellation();
      final result = await deps.library.scanner!.scan(
        cancellation: token,
        onProgress: (p) {
          if (p.checked == 3) token.cancel();
        },
      );
      expect(result.cancelled, true);
      expect(result.imported, 2);
      expect(result.missing, isEmpty);
      await deps.library.scan();
      expect(deps.library.documents, hasLength(5));
      expect(deps.library.message, contains('2 unchanged'));
    },
  );

  test('failed parsing is not cached as an unchanged file', () async {
    await File(p.join(folder.path, 'bad.md')).writeAsBytes([0xff, 0xfe]);
    await deps.library.scan();
    await deps.library.scan();
    expect(files.reads, 2);
    expect(deps.library.documents, isEmpty);
  });
}
