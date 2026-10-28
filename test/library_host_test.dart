// Switching entire library dependency graphs cancels old work and disposes database handles safely.

import 'package:omniquiz/domain/study_library.dart';

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/app/library_host.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:omniquiz/presentation/library/library_page.dart';
import 'package:omniquiz/presentation/library/library_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;
import 'support/folder_permissions.dart';

void main() {
  mockFolderPermissions();
  testWidgets(
    'an unavailable portable library keeps Settings accessible and can reopen',
    (tester) async {
      late Directory root;
      late _TrackedDatabase global;
      late LibraryCatalog catalog;
      late AppDependencies initial;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('omniquiz-reopen-');
        global = _TrackedDatabase(NativeDatabase.memory());
        catalog = LibraryCatalog(global, root.path);
        final library = await catalog.create('Reconnected course');
        await catalog.select(library);
        await File(p.join(library.directory, 'notes.md'))
            .writeAsString('Retrieval practice strengthens learning.');
        initial = await AppDependencies.create(
          database: QuizDatabase(NativeDatabase.memory()),
          settingsDatabase: global,
          credentialStore: MemoryCredentials(),
          ai: FakeGenerator(),
        );
        await initial.language.select('en');
      });
      await tester.pumpWidget(
        LibraryHost(
          catalog: catalog,
          initial: initial,
          initialUnavailable: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reopen library'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Interface language'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reopen library'));
      await tester.tap(find.text('Reopen library'));
      for (var i = 0; i < 250; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('notes.md').evaluate().isNotEmpty) break;
      }
      expect(find.text('notes.md'), findsOneWidget);
      expect(find.text('Reopen library'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 200 && !global.closed.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(global.closed.isCompleted, isTrue);
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'switching cancels generation, shows only the selected library and creates libraries on mobile',
    (tester) async {
      // Separate files/executors are intentional for library isolation.
      final previousWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarning,
      );
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late _TrackedDatabase global;
      late LibraryCatalog catalog;
      late AppDependencies initial;
      final ai = FakeGenerator()..gate = Completer<void>();
      Future<void>? generating;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('omniquiz-host-');
        global = _TrackedDatabase(
          NativeDatabase(File(p.join(root.path, 'omniquiz.sqlite'))),
        );
        catalog = LibraryCatalog(global, root.path);
        await catalog.load();
        final fixtureFolder = await Directory(
          p.join(root.path, 'fixture-materials'),
        ).create();
        catalog.libraries.add(
          StudyLibrary(
            id: 'default',
            name: 'Test library',
            directory: fixtureFolder.path,
          ),
        );
        await catalog.select(catalog.libraries.single);
        initial = await AppDependencies.create(
          database: global,
          ownsDatabase: false,
          libraryFiles: DirectoryLibraryFiles(catalog.selected.directory),
          credentialStore: MemoryCredentials(),
          ai: ai,
        );
        await initial.library.import(sample: true);
        await initial.settings.save(
          'https://example.com/v1',
          'test',
          'key',
          false,
          'English',
          false,
        );
        final physics = await catalog.create('Physics');
        await File(p.join(physics.directory, 'Physics notes.md'))
            .writeAsString('Energy is conserved.');
      });
      await tester.pumpWidget(LibraryHost(catalog: catalog, initial: initial));
      Future<void> settleWork({String? library}) async {
        for (var i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          final page = find.byType(LibraryPage);
          if (i > 1 && page.evaluate().isNotEmpty) {
            final vm = tester.element(page).read<LibraryViewModel>();
            final selector = tester.widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            );
            if (!vm.busy &&
                selector.onChanged != null &&
                (library == null || catalog.selected.name == library)) {
              return;
            }
          }
        }
        fail('Library operation did not finish.');
      }

      await settleWork();
      await tester.runAsync(() async {
        generating = initial.coordinator.start(null);
        for (var i = 0; i < 200 && ai.calls == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(ai.calls, greaterThan(0), reason: 'Generation must start.');
      });
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physics').last);
      await tester.pump();
      await settleWork(library: 'Physics');
      await tester.runAsync(() async {
        await generating;
      });
      expect(catalog.selected.name, 'Physics');
      expect(find.text('Physics notes.md'), findsOneWidget);
      expect(find.text('Learning science.md'), findsNothing);
      expect(
        await tester.runAsync(
          () => global.customSelect('SELECT * FROM questions').get(),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);

      // Exclusion is reversible through the real page, including its dialog.
      await tester.ensureVisible(find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pump();
      await settleWork(library: 'Physics');
      expect(find.text('Physics notes.md'), findsNothing);
      final excluded = find.text('Excluded files (1)');
      await tester.ensureVisible(excluded);
      await tester.tap(excluded);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import again'));
      await tester.pump();
      await settleWork(library: 'Physics');
      expect(find.text('Physics notes.md'), findsOneWidget);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.ensureVisible(find.text('Create library'));
      await tester.tap(find.text('Create library'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Biology');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pump();
      await settleWork(library: 'Biology');
      expect(catalog.selected.name, 'Biology');
      expect(find.text('Import ZIP'), findsOneWidget);
      expect(find.text('Physics notes.md'), findsNothing);
      expect(tester.takeException(), isNull);

      // Drive both Flutter microtasks and native I/O until shutdown completes.
      // Fixed delays can delete files while Windows still has SQLite open.
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 200 && !global.closed.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(
        global.closed.isCompleted,
        true,
        reason: 'Host must close its database',
      );
      await tester.runAsync(() async {
        await root.delete(recursive: true);
      });
    },
  );
}

class _TrackedDatabase extends QuizDatabase {
  _TrackedDatabase(super.executor);
  final closed = Completer<void>();

  @override
  Future<void> close() async {
    await super.close();
    closed.complete();
  }
}
