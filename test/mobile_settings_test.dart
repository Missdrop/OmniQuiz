import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/app/theme.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/settings/chatgpt_panel.dart';
import 'package:provider/provider.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final language in ['en', 'zh']) {
      testWidgets(
        '$platform $language subscription controls fit a small phone',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = QuizDatabase(NativeDatabase.memory());
          late AppDependencies deps;
          await tester.runAsync(() async {
            deps = await AppDependencies.create(
              database: db,
              credentialStore: MemoryCredentials(),
              ai: FakeGenerator(),
            );
            await deps.settings.load();
          });
          addTearDown(() async {
            await deps.dispose();
            await db.close();
          });
          deps.settings.chatGptAccounts = {
            'oaiapp_test': '${'long-account-name-' * 5}@example.test',
          };
          deps.settings.chatGptAccount = 'oaiapp_test';
          deps.settings.chatGptModels = ['other-model', 'test-model'];
          deps.settings.profile = ProviderProfile(
            baseUrl: 'https://api.openai.com/v1',
            model: 'test-model',
            credentialRef: 'oaiapp_test',
            chatGpt: true,
            language: 'English',
          );
          final l = await AppLocalizations.delegate.load(Locale(language));
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: deps.settings,
              child: MaterialApp(
                theme: buildTheme().copyWith(platform: platform),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: ChatGptPanel()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l.chatGptSignInAgain), findsOneWidget);
          await tester.ensureVisible(find.text(l.chatGptSignOut));
          final fields = find.byType(DropdownButtonFormField<String>);
          expect(fields, findsNWidgets(3));
          final account = tester.getRect(fields.at(0));
          final model = tester.getRect(fields.at(1));
          final languageField = tester.getRect(fields.at(2));
          expect(model.top - account.bottom, greaterThan(24));
          expect(languageField.top - model.bottom, greaterThanOrEqualTo(24));
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(fields.at(1))
                .initialValue,
            'test-model',
          );
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(fields.at(2))
                .initialValue,
            'English',
          );
          await tester.ensureVisible(find.text(l.testConnection));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
