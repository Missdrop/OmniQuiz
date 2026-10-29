// Verify real-engine routing, material selection and read-only answer history.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';

import '../test/ai_test.dart' show MemoryCredentials;
import '../test/coordinator_test.dart' show FakeGenerator;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('materials and history work on a native engine', (tester) async {
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: MemoryCredentials(),
      ai: FakeGenerator(),
    );
    await deps.language.select('en');
    await deps.library.import(sample: true);
    await deps.settings.save(
      'https://example.com/v1',
      'model',
      'test-key',
      false,
      'English',
      false,
    );
    await deps.coordinator.start(null);
    await deps.practice.refresh();
    deps.practice.choose('b');
    await deps.practice.submit();
    await deps.coordinator.quiesce();
    await tester.pumpWidget(OmniQuizApp(dependencies: deps));
    await tester.pumpAndSettle();
    Future<void> card(String route) async {
      final target = find.byKey(ValueKey('stat:$route'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await card('/library/materials');
    expect(find.text('Learning science.md'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(deps.library.enabledDocuments, isEmpty);
    await tester.ensureVisible(find.text('Select all'));
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(deps.library.enabledDocuments, hasLength(1));
    debugPrint('MATERIALS_NATIVE_UI_READY');
    if (const bool.fromEnvironment('UI_AUDIT_PAUSE')) {
      await Future<void>.delayed(const Duration(seconds: 8));
    }
    await tester.ensureVisible(find.text('Back to library'));
    await tester.tap(find.text('Back to library'));
    await tester.pumpAndSettle();
    await card('/library/history');
    expect(find.byType(ExpansionTile), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('Explanation'), findsOneWidget);
    debugPrint('HISTORY_NATIVE_UI_READY');
    if (const bool.fromEnvironment('UI_AUDIT_PAUSE')) {
      await Future<void>.delayed(const Duration(seconds: 8));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await deps.dispose();
  });
}
