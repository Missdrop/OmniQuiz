// Windows caption follows explicit and system-resolved interface language through a mocked native channel.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/platform/window_title.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  testWidgets('Windows caption follows the resolved interface language', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final titles = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DesktopWindowTitle.channel,
      (call) async {
        expect(call.method, 'setTitle');
        titles.add(call.arguments as String);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DesktopWindowTitle.channel,
        null,
      ),
    );
    late AppDependencies deps;
    await tester.runAsync(() async {
      deps = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        credentialStore: MemoryCredentials(),
        ai: FakeGenerator(),
      );
      await deps.language.select('en');
    });
    await tester.pumpWidget(OmniQuizApp(dependencies: deps));
    await tester.pumpAndSettle();
    expect(titles.last, 'OmniQuiz');
    await tester.runAsync(() => deps.language.select('zh'));
    await tester.pumpAndSettle();
    expect(titles.last, '万物一点通');
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'en',
      'US',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    await tester.runAsync(() => deps.language.select('system'));
    await tester.pumpAndSettle();
    expect(titles.last, 'OmniQuiz');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(deps.dispose);
    debugDefaultTargetPlatformOverride = null;
  });
}
