// Actual page geometry and readable option previews at desktop/mobile breakpoints.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/theme.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/l10n/app_localizations.dart';
import 'package:omniquiz/presentation/backup/backup_panel.dart';
import 'package:omniquiz/presentation/practice/choice_option.dart';
import 'package:omniquiz/presentation/review/review_page.dart';
import 'package:omniquiz/presentation/review/review_view_model.dart';
import 'package:omniquiz/presentation/shared/widgets.dart';
import 'package:provider/provider.dart';

import 'backup_panel_test.dart' show FakeBackupActions;
import 'persistence_test.dart' show sampleQuestion;

class _ReviewQuestions extends Fake implements QuestionRepository {
  @override
  Future<List<ReviewEntry>> reviews() async {
    final original = sampleQuestion();
    return [
      for (final prompt in [
        '水在什么温度下结冰？',
        '如果需要解释水的凝固过程，应如何根据资料判断温度变化与物态变化之间的关系？',
      ])
        ReviewEntry(
          Question(
            id: prompt,
            prompt: prompt,
            options: original.options,
            correctOptionId: original.correctOptionId,
            explanation: original.explanation,
            topic: original.topic,
            source: original.source,
            quote: original.quote,
          ),
          ReviewState(
            questionId: prompt,
            streak: 0,
            mistakes: 1,
            dueAt: DateTime.utc(2020),
          ),
        ),
    ];
  }
}

void main() {
  Future<void> loadFont(WidgetTester tester) => tester.runAsync(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(appFontFamily)..addFont(
          File('assets/fonts/NotoSansSC.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  Widget screen(
    Widget child,
    GlobalKey capture, {
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: buildTheme(brightness: brightness),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: capture,
      child: Scaffold(body: child),
    ),
  );
  Future<void> snapshot(WidgetTester tester, GlobalKey capture, String name) =>
      tester.runAsync(() async {
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
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets(
      'backup and unequal-length review entries fill the same content width at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loadFont(tester);
        final capture = GlobalKey();
        final expectedWidth = size.width < 600
            ? size.width - 40
            : (size.width - 80).clamp(0.0, 1080.0);
        final panel = BackupPanel(
          actions: FakeBackupActions(),
          runExclusive: (work) => work(),
        );
        await tester.pumpWidget(
          screen(
            PageFrame(
              eyebrow: '设置',
              title: '设置',
              subtitle: '备份与恢复',
              children: [panel],
            ),
            capture,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(Card)).width,
          closeTo(expectedWidth, .1),
        );
        await snapshot(tester, capture, 'backup-${size.width.toInt()}');
        final vm = ReviewViewModel(_ReviewQuestions());
        await vm.refresh();
        await tester.pumpWidget(
          screen(
            ChangeNotifierProvider.value(value: vm, child: const ReviewPage()),
            capture,
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byType(Card);
        expect(cards, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          expect(tester.getSize(cards.at(i)).width, closeTo(expectedWidth, .1));
        }
        expect(
          tester.getTopLeft(cards.at(0)).dx,
          tester.getTopLeft(cards.at(1)).dx,
        );
        expect(tester.takeException(), isNull);
        await snapshot(tester, capture, 'review-${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'option rows remain readable with long text and answer feedback in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loadFont(tester);
        final capture = GlobalKey();
        String? selected;
        const options = [
          '先快速浏览资料，再回忆关键概念。',
          '只看答案，不回想解题过程。',
          '尝试解释概念，并对照原文检查。',
          '短时间内重复阅读同一句话。',
        ];
        await tester.pumpWidget(
          screen(
            StatefulBuilder(
              builder: (context, setState) => PageFrame(
                eyebrow: '练习',
                title: '哪种方法更有助于理解？',
                subtitle: '选择一个答案',
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ChoiceOption(
                                label: String.fromCharCode(65 + i),
                                text: options[i],
                                selected: selected == options[i],
                                correct: selected != null && i == 2,
                                incorrect: selected == options[i] && i != 2,
                                onPressed: selected == null
                                    ? () =>
                                          setState(() => selected = options[i])
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            capture,
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        await snapshot(tester, capture, 'options-${brightness.name}');
        await tester.ensureVisible(find.text(options[1]));
        await tester.tap(find.text(options[1]));
        await tester.pumpAndSettle();
        expect(selected, options[1]);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(tester.takeException(), isNull);
        await snapshot(tester, capture, 'options-${brightness.name}-answered');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
