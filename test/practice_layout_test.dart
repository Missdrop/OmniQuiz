// The real practice page keeps a compact toolbar and groups source/feedback at the bottom.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/app/theme.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/presentation/practice/choice_option.dart';
import 'package:omniquiz/presentation/practice/guidance_dialog.dart';
import 'package:omniquiz/presentation/practice/practice_toolbar.dart';
import 'package:omniquiz/presentation/practice/source_viewer.dart';
import 'package:omniquiz/presentation/settings/connection_manager.dart';
import 'package:omniquiz/presentation/settings/settings_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

class _PracticeAi extends FakeGenerator {
  @override
  Future<List<Question>> generate(GenerationRequest request) async => [
    for (final q in await super.generate(request))
      Question(
        id: q.id,
        prompt: q.id == '1-0'
            ? '哪一种学习方法更有助于长期记忆？'
            : '哪一种学习方法更有助于长期记忆？（练习 ${q.id}）',
        options: const [
          AnswerOption('a', '反复阅读，直到感觉熟悉'),
          AnswerOption('b', '先尝试回忆，再对照资料检查'),
          AnswerOption('c', '把所有内容一次性背完'),
          AnswerOption('d', '只标记重点，不进行练习'),
        ],
        correctOptionId: 'b',
        explanation: '主动回忆让你发现知识缺口，再通过原文核对和及时反馈巩固记忆。',
        topic: '主动回忆',
        source: q.source,
        quote: q.quote,
      ),
  ];
}

void main() {
  testWidgets(
    'A layout preserves the current UI, source expansion, selection and session controls',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );
      late AppDependencies deps;
      final ai = _PracticeAi();
      await tester.runAsync(() async {
        await (FontLoader(appFontFamily)..addFont(
              File('assets/fonts/NotoSansSC.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        deps = await AppDependencies.create(
          database: QuizDatabase(NativeDatabase.memory()),
          credentialStore: MemoryCredentials(),
          ai: ai,
        );
        await deps.language.select('zh');
        await deps.appearance.select(ThemeMode.light);
        await deps.library.import(sample: true, chineseSample: true);
        await deps.settings.saveApiConnection(
          name: '学习助手',
          url: 'https://example.test/v1',
          model: 'gpt-6.1-sol',
          key: 'fixture-only',
        );
      });
      final capture = GlobalKey();
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      Future<void> snapshot(String name) => tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('.tooling/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: OmniQuizApp(dependencies: deps),
          ),
        );
        await settle();
        await tester.tap(find.text('练习').first);
        await settle();
        await tester.runAsync(deps.practice.startPractice);
        await tester.runAsync(deps.practice.refresh);
        await settle();
        expect(tester.getTopLeft(find.byType(Card).first).dy, lessThan(200));
        expect(find.byType(PracticeToolbar), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('好')).dy,
          greaterThan(tester.getBottomLeft(find.byType(ChoiceOption).last).dy),
        );
        expect(
          (tester.getCenter(find.text('好')).dy -
                  tester.getCenter(find.text('查看原始资料')).dy)
              .abs(),
          lessThan(2),
        );
        await snapshot('practice-a-current-desktop');
        final current = deps.practice.current!.id;
        final calls = ai.calls;
        await tester.tap(find.byIcon(Icons.hub_outlined));
        await settle();
        expect(find.byType(ConnectionManager), findsOneWidget);
        await tester.tap(find.byType(BackButton).last);
        await settle();
        expect(deps.practice.current!.id, current);
        expect(ai.calls, calls);
        await tester.tap(find.text('出题设置'));
        await settle();
        expect(find.byType(GuidanceDialog), findsOneWidget);
        await tester.tap(find.text('取消'));
        await settle();
        expect(ai.calls, calls);
        await tester.tap(find.text('查看原始资料'));
        await settle();
        expect(find.byType(SourceViewer), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        await tester.ensureVisible(find.text('收起原始资料'));
        await tester.tap(find.text('收起原始资料'));
        await settle();
        await tester.ensureVisible(find.byType(PracticeToolbar));
        tester.view.physicalSize = const Size(390, 844);
        tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;
        await tester.runAsync(() => deps.appearance.select(ThemeMode.dark));
        await settle();
        expect(tester.takeException(), isNull);
        await snapshot('practice-a-current-mobile');
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, '先尝试回忆，再对照资料检查'),
        );
        await tester.tap(find.widgetWithText(OutlinedButton, '先尝试回忆，再对照资料检查'));
        await settle();
        expect(deps.practice.answered, isTrue);
        expect(deps.practice.selected, 'b');
        await tester.ensureVisible(find.text('下一题'));
        await tester.tap(find.text('下一题'));
        await settle();
        expect(deps.practice.current!.id, isNot(current));
        await tester.ensureVisible(find.text('结束练习'));
        await tester.tap(find.text('结束练习'));
        await settle();
        expect(deps.practice.active, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(deps.dispose);
      }
    },
  );
}
