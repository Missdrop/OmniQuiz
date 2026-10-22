import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/main.dart' as app;
import 'package:omniquiz/presentation/library/create_library_dialog.dart';
import 'package:omniquiz/presentation/settings/model_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../test/ai_test.dart' show MemoryCredentials;
import '../test/coordinator_test.dart' show FakeGenerator;

// Runs on a native simulator/device. Fixtures keep populated UI checks offline;
// the first scenario uses the normal application and its persistent library.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: name);
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/ui-audit',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(await binding.takeScreenshot(name));
    debugPrint('UI_AUDIT: $name');
    if (const bool.fromEnvironment('UI_AUDIT_PAUSE') &&
        name.contains('keyboard')) {
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('native library, keyboard, settings and language interaction', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    await capture(tester, '01-library');
    await tap(tester, find.byIcon(Icons.create_new_folder_outlined).first);
    expect(find.byType(CreateLibraryDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'iOS UI check');
    await tester.pumpAndSettle();
    await capture(tester, '02-create-library-keyboard');
    expect(
      View.of(tester.element(find.byType(TextField))).viewInsets.bottom,
      greaterThan(0),
      reason: 'Native software keyboard must be visible',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    expect(find.byType(CreateLibraryDialog), findsNothing);
    expect(find.text('iOS UI check'), findsWidgets);

    await tap(tester, find.byIcon(Icons.tune_rounded));
    for (final language in ['English', '简体中文']) {
      final picker = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('interface-'),
      );
      await tap(tester, picker);
      await tap(tester, find.text(language).last);
      await capture(
        tester,
        language == 'English' ? '03-settings-en' : '04-settings-zh',
      );
    }
    await tap(tester, find.byIcon(Icons.auto_stories_outlined));
    await tap(tester, find.text('体验示例资料'));
    await capture(tester, '05-imported-library');
    await tap(tester, find.byIcon(Icons.play_circle_outline));
    await tap(tester, find.text('生成题目'));
    await capture(tester, '06-generation-confirmation');
    await tap(tester, find.text('取消'));
    await tap(tester, find.byIcon(Icons.history_rounded));
    await capture(tester, '07-empty-review');
  });

  testWidgets('native populated account, model picker, answer and review UI', (
    tester,
  ) async {
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    await deps.settings.load();
    await deps.language.select('en');
    await deps.library.import(sample: true);
    await deps.settings.save(
      'https://example.com/v1',
      'test-model',
      'fixture',
      false,
      'English',
      false,
    );
    await deps.coordinator.start(null);
    await deps.coordinator.stop();
    await deps.practice.refresh();
    deps.settings.profile = ProviderProfile(
      baseUrl: 'https://api.openai.com/v1',
      model: 'test-model',
      credentialRef: 'oaiapp_fixture',
      chatGpt: true,
      language: 'English',
    );
    deps.settings.chatGptAccount = 'oaiapp_fixture';
    deps.settings.chatGptAccounts = {
      'oaiapp_fixture': 'long-account-name-for-layout@example.test · fixture',
    };
    deps.settings.chatGptModels = ['other-model', 'test-model'];
    runApp(OmniQuizApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tap(tester, find.byIcon(Icons.tune_rounded));
    await tester.ensureVisible(find.text('Sign in again'));
    await capture(tester, '08-account');
    await tester.ensureVisible(find.text('Test and use this model'));
    await capture(tester, '09-model-language');
    final model = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.initialValue == 'test-model',
    );
    await tap(tester, model);
    await capture(tester, '10-model-dropdown');
    await tap(tester, find.text('other-model').last);

    // Exercise the same searchable modal used by API model discovery, offline.
    final context = tester.element(find.byType(Scaffold).first);
    showDialog<String>(
      context: context,
      builder: (_) => const ModelPicker(models: ['test-model', 'other-model']),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, 'other');
    await capture(tester, '11-search-keyboard');
    await tap(tester, find.text('other-model').last);
    expect(find.byType(ModelPicker), findsNothing);

    await tap(tester, find.byIcon(Icons.play_circle_outline));
    await tap(tester, find.widgetWithText(OutlinedButton, 'B').first);
    await tap(tester, find.text('Check answer'));
    await tester.ensureVisible(find.text('A useful mistake.'));
    await capture(tester, '12-answer-feedback');
    await tap(tester, find.byIcon(Icons.history_rounded));
    await capture(tester, '13-review');
    await tap(tester, find.textContaining(RegExp(r'^Review (now|early)$')));
    expect(deps.practice.reviewing, isTrue);
    await capture(tester, '14-review-practice');
    runApp(const SizedBox());
    await tester.pumpAndSettle();
    await deps.dispose();
  });
}
