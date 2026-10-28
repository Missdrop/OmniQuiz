// Store-flavor update isolation plus bundled offline policies; no live account or provider is required.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/app/distribution.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/settings/privacy_policy_page.dart';
import 'package:omniquiz/presentation/updates/update_controller.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;
import 'update_test.dart'
    show
        MemoryUpdatePreferences,
        FixtureUpdater,
        FixtureInstaller,
        releaseFixture;

void main() {
  test('Store controller cannot check GitHub, download or install standalone releases', () async {
    final service = FixtureUpdater();
    final installer = FixtureInstaller();
    final vm = UpdateController(
      MemoryUpdatePreferences(),
      storeBuild: true,
      service: service,
      installer: installer,
      versionReader: () async => '1.0.0',
    );
    await vm.initialize();
    await vm.setAutoCheck(true);
    await vm.check();
    vm.release = releaseFixture();
    vm.asset = vm.release!.assets.first;
    vm.downloaded = File('unused.msi');
    await vm.download();
    await vm.install();
    expect(service.checks, 0);
    expect(service.downloads, 0);
    expect(installer.installs, 0);
    expect(vm.autoCheck, isFalse);
    vm.dispose();
  });

  testWidgets('privacy policy is available offline in English and Chinese', (
    tester,
  ) async {
    for (final language in ['en', 'zh']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PrivacyPolicyPage(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      final text = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(text, contains('Missdrop'));
      expect(text, contains('https://github.com/Missdrop/OmniQuiz/issues'));
      expect(
        text,
        contains(
          language == 'zh' ? '操作系统的安全存储' : 'operating-system secure storage',
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('settings use the update channel selected at compilation', (
    tester,
  ) async {
    late AppDependencies deps;
    await tester.runAsync(() async {
      deps = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        credentialStore: MemoryCredentials(),
        ai: FakeGenerator(),
      );
      await deps.language.select('en');
      await deps.settings.load();
    });
    await tester.pumpWidget(OmniQuizApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Open Microsoft Store'),
      microsoftStoreBuild ? findsOneWidget : findsNothing,
    );
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Report AI content to developer'), findsOneWidget);
    expect(find.text('Check for updates'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(deps.dispose);
  });
}
