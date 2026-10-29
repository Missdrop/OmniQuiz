// Fresh installs start empty and share system-default preferences while keeping library data isolated.

import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/app/library_host.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:omniquiz/infrastructure/persistence/preferences_repository.dart';
import 'package:omniquiz/presentation/settings/question_language_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;
import 'support/folder_permissions.dart';

class _LanguageGenerator extends FakeGenerator {
  final languages = <String>[];
  @override
  Future<List<Question>> generate(GenerationRequest request) {
    languages.add(request.profile.language);
    return super.generate(request);
  }
}

void main() {
  mockFolderPermissions();
  final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning,
  );
  testWidgets(
    'first launch has no library, all preferences follow system, and first library can be created',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late LibraryCatalog catalog;
      late AppDependencies deps;
      late _TrackedDatabase global;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('omniquiz-first-launch-');
        global = _TrackedDatabase(NativeDatabase.memory());
        catalog = LibraryCatalog(global, root.path);
        await catalog.load();
        expect(catalog.libraries, isEmpty);
        expect(await Directory('${root.path}/libraries').exists(), isFalse);
        deps = await AppDependencies.create(
          database: QuizDatabase(NativeDatabase.memory()),
          settingsDatabase: global,
          credentialStore: MemoryCredentials(),
          ai: FakeGenerator(),
        );
        expect(deps.appearance.mode, ThemeMode.system);
        expect(deps.language.language, 'system');
        expect(deps.questionLanguage.language, 'system');
        await deps.language.select('en');
      });
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.pumpWidget(LibraryHost(catalog: catalog, initial: deps));
      await settle();
      expect(find.text('Default'), findsNothing);
      expect(find.text('Create your first library'), findsOneWidget);
      expect(find.text('Import files'), findsNothing);
      await tester.tap(find.text('Settings').first);
      await settle();
      expect(find.text('Question language'), findsOneWidget);
      final interfaceField = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.key == const ValueKey('interface-en'),
      );
      final questionField = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.key == const ValueKey('question-language-system'),
      );
      expect(
        tester.getTopLeft(questionField).dy,
        greaterThan(tester.getBottomLeft(interfaceField).dy),
      );
      await tester.tap(find.text('Library').first);
      await settle();
      await tester.tap(find.text('Create library'));
      await settle();
      await tester.enterText(find.byType(TextField).first, 'My course');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      // Portable initialization performs several real filesystem operations;
      // allow each completion to cross the widget test's fake-async boundary.
      for (var i = 0; i < 200 && catalog.selectedId.isEmpty; i++) {
        await settle();
      }
      await settle();
      expect(catalog.libraries, hasLength(1));
      expect(catalog.selected.name, 'My course');
      expect(find.text('Import files'), findsNothing);
      for (
        var i = 0;
        i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await settle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('stat:/library/materials')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('stat:/library/materials')));
      await settle();
      expect(find.text('Import files'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 50 && !global.closed.isCompleted; i++) {
        await settle();
      }
      expect(global.closed.isCompleted, isTrue);
      await tester.runAsync(() async {
        await root.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'global question language overrides both providers, follows OS locale and persists independently',
    (tester) async {
      final systemLanguage = ui.PlatformDispatcher.instance.locale
          .toLanguageTag();
      await tester.runAsync(() async {
        final ai = _LanguageGenerator();
        final deps = await AppDependencies.create(
          database: QuizDatabase(NativeDatabase.memory()),
          credentialStore: MemoryCredentials(),
          ai: ai,
        );
        try {
          await deps.library.import(sample: true);
          expect(deps.questionLanguage.resolved, systemLanguage);
          await deps.settings.save(
            'https://example.test/v1',
            'model',
            'key',
            false,
            'English',
            false,
          );
          await deps.practice.startPractice();
          await deps.practice.endPractice();
          expect(ai.languages.toSet(), {systemLanguage});
          await deps.questionLanguage.select('English');
          final restored = QuestionLanguageViewModel(
            SqlPreferencesRepository(deps.database),
          );
          await restored.load();
          expect(restored.language, 'English');
          restored.dispose();
          await deps.settings.profiles.save(
            ProviderProfile(
              baseUrl: 'https://api.openai.com/v1',
              model: 'subscription',
              credentialRef: 'oaiapp_fixture',
              chatGpt: true,
              language: '简体中文',
            ),
          );
          for (final q in await deps.practice.questions.ready(null)) {
            await deps.practice.questions.flagQuestion(q.id);
          }
          ai.languages.clear();
          await deps.practice.startPractice();
          await deps.practice.endPractice();
          expect(ai.languages.toSet(), {'English'});
          expect(deps.language.language, 'system');
          expect(deps.appearance.mode, ThemeMode.system);
        } finally {
          await deps.dispose();
        }
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
    if (!closed.isCompleted) closed.complete();
  }
}
