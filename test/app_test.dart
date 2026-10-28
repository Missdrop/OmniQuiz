// End-to-end widget flow for import, setup, answering and review across desktop and mobile layouts.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  testWidgets(
    'import, configure, generate, answer and review on desktop and phone',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AppDependencies deps;
      await tester.runAsync(() async {
        deps = await AppDependencies.create(
          database: QuizDatabase(NativeDatabase.memory()),
          credentialStore: MemoryCredentials(),
          ai: FakeGenerator(),
        );
        await deps.library.refresh();
        await deps.settings.load();
      });
      await tester.runAsync(() async {
        final localFont = File(
          '.tooling/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        );
        if (await localFont.exists()) {
          final loader = FontLoader('Roboto')
            ..addFont(
              localFont.readAsBytes().then((b) => ByteData.sublistView(b)),
            );
          await loader.load();
        }
      });
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await iconLoader.load();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: OmniQuizApp(dependencies: deps),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your next chapter starts here'), findsOneWidget);
      await tester.runAsync(() async {
        await deps.library.import(sample: true);
        await deps.settings.save(
          'https://example.com/v1',
          'test-model',
          'test-key',
          false,
          'English',
          false,
        );
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Learning science.md'), findsOneWidget);
      await tester.tap(find.text('Practice').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await deps.coordinator.start(null);
        await deps.practice.refresh();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('20 ready'), findsOneWidget);
      expect(deps.practice.current, isNotNull);
      await tester.tap(find.widgetWithText(OutlinedButton, 'B').first);
      await tester.pump();
      expect(find.text('Check answer'), findsNothing);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('A useful mistake.'), findsOneWidget);
      expect(deps.practice.answered, true);
      await tester.runAsync(() async {
        await deps.review.refresh();
      });
      expect(deps.review.entries.length, 1);
      await tester.tap(find.text('Review').first);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1/3 correct reviews · 1 missed'), findsNothing);
      expect(find.text('0/3 correct reviews · 1 missed'), findsOneWidget);
      await tester.tap(find.text('Settings').first);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('test-model'), findsOneWidget);
      expect(find.text('test-key'), findsNothing);
      await tester.tap(find.text('Library').first);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.tooling/previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('library-desktop');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('library-mobile');
      await tester.tap(find.text('Practice').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await capture('practice-mobile');
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await deps.practice.next();
        expect(deps.practice.current, isNotNull);
        await deps.library.remove(deps.library.documents.single.id);
        await deps.practice.refresh();
        expect(deps.practice.current, isNull);
        expect(deps.practice.readyCount, 0);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(deps.dispose);
    },
  );
}
