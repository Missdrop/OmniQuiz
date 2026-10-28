// Live UI language changes preserve provider drafts and remain navigable with accessibility text scaling.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/application/ports/preferences_repository.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/preferences_repository.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/settings/language_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

class UnwritablePreferences implements PreferencesRepository {
  @override
  Future<String?> loadInterfaceLanguage() async => 'en';
  @override
  Future<void> saveInterfaceLanguage(String language) async =>
      throw const FileSystemException('Read only');
}

void main() {
  test(
    'language survives database reopen and does not change generation epoch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'omniquiz-locale-',
      );
      final file = File('${directory.path}/quiz.sqlite');
      final first = QuizDatabase(NativeDatabase(file));
      final preference = LanguageViewModel(SqlPreferencesRepository(first));
      await preference.load();
      expect(preference.locale, isNull);
      await preference.select('zh');
      expect(
        (await first
                .customSelect("SELECT value FROM settings WHERE key='epoch'")
                .getSingle())
            .read<String>('value'),
        '0',
      );
      preference.dispose();
      await first.close();
      final reopened = QuizDatabase(NativeDatabase(file));
      final restored = LanguageViewModel(SqlPreferencesRepository(reopened));
      await restored.load();
      expect(restored.locale, const Locale('zh'));
      await restored.select('system');
      expect(
        await SqlPreferencesRepository(reopened).loadInterfaceLanguage(),
        'system',
      );
      restored.dispose();
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'failed preference write keeps previous language and reports failure',
    () async {
      final model = LanguageViewModel(UnwritablePreferences());
      await model.load();
      await model.select('zh');
      expect(model.language, 'en');
      expect(model.saveFailed, isTrue);
      expect(model.saving, isFalse);
      model.dispose();
    },
  );

  test('Chinese diagnostics retain filenames, counts, and source locations', () async {
    final l = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(
      l.diagnostic('notes.md: Text files must use UTF-8 encoding.'),
      'notes.md: 文本文件必须使用 UTF-8 编码。',
    );
    expect(l.diagnostic('2 imported · 1 unchanged'), '已导入 2 份 · 1 份无变化');
    expect(l.diagnostic('Retrying generation (2/3)…'), '正在重试生成（2/3）…');
    expect(
      l.diagnostic(
        'Provider returned HTTP 400. Check the base URL, model and JSON mode.',
      ),
      contains('HTTP 400'),
    );
    expect(
      l.sourceLocation('Page 3 · characters 1–2400'),
      '第 3 页 · 第 1–2400 个字符',
    );
    expect(
      l.diagnostic('Unrecognized user content'),
      'Unrecognized user content',
    );
  });

  testWidgets(
    'interface switches live without saving AI settings, with Chinese mobile workflow',
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
        await deps.settings.load();
        await deps.language.select('en');
        await deps.library.import(sample: true, chineseSample: true);
        final font = File('C:/Windows/Fonts/msyh.ttc');
        if (await font.exists()) {
          for (final family in ['Roboto', 'Segoe UI']) {
            final loader = FontLoader(family)
              ..addFont(font.readAsBytes().then(ByteData.sublistView));
            await loader.load();
          }
        }
      });
      Future<void> settle() async {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }

      final boundary = GlobalKey();
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await iconLoader.load();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.tooling/previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: OmniQuizApp(dependencies: deps),
        ),
      );
      await settle();
      await tester.tap(find.text('Settings').first);
      await settle();
      await tester.ensureVisible(find.byKey(const ValueKey('interface-en')));
      await tester.tap(find.byKey(const ValueKey('interface-en')));
      await settle();
      await tester.tap(find.text('简体中文').last);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle();
      expect(find.text('界面语言'), findsOneWidget);
      expect(find.text('万物一点通'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('配置 AI'), findsOneWidget);
      expect(deps.settings.profile, isNull);
      expect(deps.language.language, 'zh');
      await capture('settings-zh-desktop');

      tester.view.physicalSize = const Size(390, 844);
      await settle();
      expect(tester.takeException(), isNull);
      await capture('settings-zh-mobile');
      await tester.tap(find.text('资料库').last);
      await settle();
      expect(
        deps.library.documents,
        isNotEmpty,
        reason: 'busy=${deps.library.busy}; message=${deps.library.message}',
      );
      expect(deps.library.documents.single.name, '学习方法示例.md');
      expect(find.text('已导入 1 份 · 0 份无变化'), findsOneWidget);
      await capture('library-zh-mobile');
      await tester.tap(find.text('练习').last);
      await settle();
      expect(find.text('开始练习'), findsOneWidget);
      expect(find.text('生成题目'), findsNothing);
      await tester.runAsync(() async {
        await deps.settings.save(
          'https://example.com/v1',
          'model',
          'key',
          false,
          'English',
          false,
        );
        await deps.coordinator.start(null);
        await deps.practice.refresh();
      });
      await settle();
      expect(find.text('20 道待答'), findsOneWidget);
      expect(deps.settings.profile!.language, deps.questionLanguage.resolved);
      expect(deps.language.language, 'zh');
      await tester.runAsync(() async {
        deps.practice.choose('b');
        await deps.practice.submit();
        await deps.review.refresh();
      });
      await settle();
      expect(find.text('这次错题，就是下次进步的起点。'), findsOneWidget);
      await tester.tap(find.text('错题复习').last);
      await settle();
      expect(find.text('已连续答对 0/3 次 · 累计答错 1 次'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.runAsync(() => deps.language.select('system'));
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('zh', 'CN'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await settle();
      expect(find.text('值得再练一次。'), findsOneWidget);
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('en', 'US'),
      ];
      await settle();
      expect(find.text('Worth another look.'), findsOneWidget);
      // Keep navigation reachable in a short desktop window and on a small
      // phone with accessibility text, including populated practice/review.
      for (final size in [const Size(900, 360), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
        for (final icon in [
          Icons.auto_stories_outlined,
          Icons.play_circle_outline,
          Icons.history_rounded,
          Icons.tune_rounded,
        ]) {
          await settle();
          await tester.ensureVisible(find.byIcon(icon).first);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(icon).first);
          await settle();
          expect(tester.takeException(), isNull, reason: '$size $icon');
        }
      }
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(deps.dispose);
    },
  );
}
