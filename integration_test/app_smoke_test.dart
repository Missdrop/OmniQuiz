import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omniquiz/main.dart' as app;
import 'package:omniquiz/presentation/settings/chatgpt_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native app starts and switches settings language', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ChatGptPanel), findsOneWidget);

    for (final language in ['English', '简体中文']) {
      final languagePicker = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('interface-'),
      );
      await tester.ensureVisible(languagePicker);
      await tester.tap(languagePicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text(language).last);
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'English' ? 'Interface language' : '界面语言'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
