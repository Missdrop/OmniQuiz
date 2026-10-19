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

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
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
      late QuizDatabase global;
      late LibraryCatalog catalog;
      late AppDependencies initial;
      final ai = FakeGenerator()..gate = Completer<void>();
      Future<void>? generating;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('omniquiz-host-');
        global = QuizDatabase(
          NativeDatabase(File(p.join(root.path, 'omniquiz.sqlite'))),
        );
        catalog = LibraryCatalog(global, root.path);
        await catalog.load();
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
      Future<void> settleWork() async {
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settleWork();
      await tester.runAsync(() async {
        generating = initial.coordinator.start(null);
        while (ai.calls == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physics').last);
      await tester.pump();
      await settleWork();
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

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.ensureVisible(find.text('Create library'));
      await tester.tap(find.text('Create library'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Biology');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pump();
      await settleWork();
      expect(catalog.selected.name, 'Biology');
      expect(find.text('Physics notes.md'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      // Allow the host to close its session and native worker on unmount.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await root.delete(recursive: true);
      });
    },
  );
}
