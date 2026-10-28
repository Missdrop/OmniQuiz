// Appearance persistence and live switching without invalidating or stopping an active practice session.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/preferences_repository.dart';
import 'package:omniquiz/presentation/settings/appearance_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  test(
    'theme survives reopening without invalidating pending generation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'omniquiz-appearance-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/settings.sqlite');
      var db = QuizDatabase(NativeDatabase(file));
      var deps = await AppDependencies.create(
        database: db,
        credentialStore: MemoryCredentials(),
        ai: FakeGenerator(),
      );
      final epoch = await deps.coordinator.jobs.epoch();
      await deps.appearance.select(ThemeMode.dark);
      expect(await deps.coordinator.jobs.epoch(), epoch);
      await deps.dispose();
      db = QuizDatabase(NativeDatabase(file));
      final restored = AppearanceViewModel(SqlPreferencesRepository(db));
      await restored.load();
      expect(restored.mode, ThemeMode.dark);
      restored.dispose();
      await db.close();
    },
  );

  testWidgets(
    'light/dark toggle works without leaving an active practice session',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AppDependencies deps;
      final ai = FakeGenerator();
      await tester.runAsync(() async {
        deps = await AppDependencies.create(
          database: QuizDatabase(NativeDatabase.memory()),
          credentialStore: MemoryCredentials(),
          ai: ai,
        );
        await deps.language.select('en');
        await deps.library.import(sample: true);
        await deps.settings.save(
          'https://example.test/v1',
          'test',
          'key',
          false,
          'English',
          false,
        );
      });

      await tester.pumpWidget(OmniQuizApp(dependencies: deps));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Practice').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(deps.practice.startPractice);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('End practice'), findsOneWidget);
      final calls = ai.calls;
      // The visible label is part of the desktop hit target, not just its icon.
      await tester.tap(find.text('Appearance'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(deps.appearance.mode, ThemeMode.dark);
      final scaffold = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(scaffold).brightness, Brightness.dark);
      expect(deps.practice.active, isTrue);
      expect(ai.calls, calls);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Library').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(deps.practice.active, isFalse);
      await tester.tap(find.text('Practice').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Start practice'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(deps.dispose);
    },
  );
}
