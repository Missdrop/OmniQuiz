// Exercises the real native PDF parser and guidance editor with public synthetic samples.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/presentation/practice/source_viewer.dart';
import 'package:omniquiz/domain/generation_guidance.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/library_catalog.dart';
import 'package:omniquiz/infrastructure/platform/library_files.dart';

import '../test/ai_test.dart' show MemoryCredentials;
import '../test/generation_guidance_test.dart'
    show SamplePicker, GuidanceGenerator;

/// Tiny real text PDF with correct xref offsets, sufficient to exercise native PDFium.
List<int> samplePdf() {
  const content =
      'BT /F1 12 Tf 50 730 Td (STYLE_SAMPLE_ONLY: compare scenarios and choose one of four answers.) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
  ];
  var value = '%PDF-1.4\n';
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(value.length);
    value += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = value.length;
  value += 'xref\n0 ${offsets.length}\n0000000000 65535 f \n';
  for (final offset in offsets.skip(1)) {
    value += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  value +=
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return ascii.encode(value);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native one-tap answer, rendered PDF page and local feedback use a portable library',
    (tester) async {
      final root = await Directory.systemTemp.createTemp(
        'omniquiz-native-portable-',
      );
      final global = QuizDatabase(NativeDatabase.memory());
      final catalog = LibraryCatalog(global, root.path);
      final library = await catalog.create('PDF course');
      final picker = SamplePicker()
        ..inputs = [
          ImportInput(
            name: 'course.pdf',
            origin: 'fixture',
            bytes: samplePdf(),
          ),
        ];
      final deps = await AppDependencies.create(
        database: await catalog.openLibrary(library),
        settingsDatabase: global,
        libraryFiles: DirectoryLibraryFiles(library.directory),
        documentAccess: picker,
        credentialStore: MemoryCredentials(),
        ai: GuidanceGenerator(),
      );
      try {
        await deps.language.select('en');
        await deps.library.import();
        final references = await deps.guidance.importExamples([]);
        expect(
          await deps.guidance.save(
            GenerationGuidance(
              requirements: 'Prefer scenarios.',
              examples: references,
            ),
          ),
          isTrue,
        );
        await deps.guidance.load();
        expect(
          deps.guidance.value.examples.single.text,
          contains('STYLE_SAMPLE_ONLY'),
        );
        expect(
          await deps.guidance.save(
            GenerationGuidance(
              requirements: 'Short scenarios.',
              examples: deps.guidance.value.examples,
            ),
          ),
          isTrue,
        );
        final storedPaper = File(
          p.join(
            library.directory,
            '.omniquiz',
            'guidance',
            'examples',
            'course.pdf',
          ),
        );
        expect(
          await storedPaper.readAsBytes(),
          samplePdf(),
          reason: 'Editing requirements preserves original PDF bytes',
        );
        await deps.settings.save(
          'https://example.test/v1',
          'test-model',
          'key',
          false,
          'English',
          false,
        );
        await deps.practice.startPractice();
        await deps.practice.refresh();
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: OmniQuizApp(dependencies: deps),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_outline).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'B').first,
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'B').first);
        while (deps.practice.busy) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(deps.practice.answered, isTrue);
        expect((await deps.practice.questions.stats()).attempts, 1);
        expect(find.text('Check answer'), findsNothing);
        await tester.ensureVisible(find.text('Good'));
        await tester.tap(find.text('Good'));
        while (deps.practice.busy) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(deps.practice.rating?.name, 'good');
        await tester.ensureVisible(find.text('View original source'));
        await tester.tap(find.text('View original source'));
        PdfViewerController? viewer;
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(PdfViewer).evaluate().isNotEmpty) {
            viewer = tester
                .widget<PdfViewer>(find.byType(PdfViewer))
                .controller;
            if (viewer?.isReady == true) break;
          }
        }
        expect(viewer?.isReady, isTrue);
        expect(viewer!.pageCount, 1);
        expect(find.byType(Dialog), findsNothing);
        await tester.ensureVisible(find.byType(SourceViewer));
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
        expect(
          (await viewer.document.pages.first.loadText())!.fullText,
          contains('STYLE_SAMPLE_ONLY'),
        );
        await tester.pump(const Duration(milliseconds: 500));
        if (Platform.isWindows) {
          final image =
              await (capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('.tooling/portable-pdf-view.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
        if (const bool.fromEnvironment('UI_AUDIT_PAUSE')) {
          debugPrint('PORTABLE_PDF_UI_READY');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 10)),
          );
        }
        await tester.ensureVisible(find.text('Hide source'));
        await tester.tap(find.text('Hide source'));
        await tester.pumpAndSettle();
        await File(deps.library.documents.single.origin)
            .writeAsString('Changed original.');
        await tester.ensureVisible(find.text('View original source'));
        await tester.tap(find.text('View original source'));
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 40 &&
              find
                  .textContaining('The original PDF is missing')
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.textContaining('The original PDF is missing'),
          findsOneWidget,
        );
        expect(find.byType(PdfViewer), findsNothing);
        await tester.ensureVisible(find.text('Hide source'));
        await tester.tap(find.text('Hide source'));
        await tester.pumpAndSettle();
        expect(
          await File(p.join(library.directory, '.omniquiz', 'quiz.sqlite'))
              .exists(),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await deps.dispose();
        await global.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'native guidance editor parses PDF, saves requirements and preserves history',
    (tester) async {
      final picker = SamplePicker()
        ..inputs = [
          ImportInput(
            name: 'reference-paper.pdf',
            origin: 'fixture',
            bytes: samplePdf(),
          ),
        ];
      final ai = GuidanceGenerator();
      final deps = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        credentialStore: MemoryCredentials(),
        documentAccess: picker,
        ai: ai,
      );
      await deps.language.select('zh');
      await deps.library.import(sample: true, chineseSample: true);
      await deps.settings.save(
        'https://example.test/v1',
        'test-model',
        'key',
        false,
        '简体中文',
        false,
      );
      // Desktop size overrides exercise responsive breakpoints. Native phones
      // retain their real pixel ratio so keyboard/safe-area insets stay valid.
      if (Platform.isWindows) {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
      }
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: OmniQuizApp(dependencies: deps),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_circle_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('出题设置'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('questions-per-batch')),
            )
            .controller!
            .text,
        '10',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('refill-threshold')),
            )
            .controller!
            .text,
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('questions-per-batch')),
        '7',
      );
      await tester.enterText(
        find.byKey(const ValueKey('refill-threshold')),
        '3',
      );
      await tester.ensureVisible(find.widgetWithText(TextField, '额外出题要求'));
      await tester.enterText(
        find.widgetWithText(TextField, '额外出题要求'),
        '中等难度，偏重概念应用。解析说明干扰项为什么不正确。',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '粘贴样题或样卷内容（可选）'),
        '请参考这样的表达：在下列情境中，哪一种学习方式最符合主动回忆？',
      );
      await tester.ensureVisible(find.text('导入样题／样卷'));
      await tester.tap(find.text('导入样题／样卷'));
      while (deps.guidance.busy) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.text('reference-paper.pdf'), findsOneWidget);
      expect(deps.library.documents, hasLength(1));
      Future<void> snapshot(String name) async {
        final image =
            await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (Platform.isWindows) {
          await File('.tooling/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        }
        image.dispose();
      }

      await snapshot('guidance-editor-desktop');
      if (Platform.isWindows) {
        tester.view.physicalSize = const Size(390, 844);
        await tester.binding.setSurfaceSize(const Size(390, 844));
      }
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;
      await deps.appearance.select(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot('guidance-editor-phone');
      if (Platform.isIOS && const bool.fromEnvironment('UI_AUDIT_PAUSE')) {
        debugPrint('GUIDANCE_UI_READY');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 12)),
        );
      }
      await tester.ensureVisible(find.text('保存出题设置'));
      await tester.tap(find.text('保存出题设置'));
      while (deps.guidance.busy) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(
        deps.guidance.value.examples.single.text,
        contains('STYLE_SAMPLE_ONLY'),
      );
      expect(deps.guidance.value.requirements, contains('概念应用'));
      expect(deps.guidance.value.questionsPerBatch, 7);
      expect(deps.guidance.value.refillThreshold, 3);
      await deps.practice.startPractice();
      await deps.practice.refresh();
      await tester.pumpAndSettle();
      expect(ai.requests.first.referenceExamples, hasLength(2));
      expect(ai.requests.first.count, 7);
      expect(ai.requests.first.additionalRequirements, contains('干扰项'));
      deps.practice.choose('b');
      await deps.practice.submit();
      await deps.practice.next();
      await deps.guidance.save(GenerationGuidance(requirements: '改为进阶难度。'));
      while (deps.coordinator.status.running) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await deps.practice.endPractice();
      expect((await deps.practice.questions.stats()).attempts, 1);
      expect(await deps.practice.questions.reviews(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await deps.dispose();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    },
  );
}
