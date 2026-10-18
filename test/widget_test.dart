import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/theme.dart';

void main() {
  testWidgets('theme renders an accessible action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: FilledButton(
            onPressed: () {},
            child: const Text('Start practice'),
          ),
        ),
      ),
    );
    expect(find.text('Start practice'), findsOneWidget);
  });
}
