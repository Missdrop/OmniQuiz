import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/application/ports/backup.dart';
import 'package:omniquiz/l10n/app_localizations.dart';
import 'package:omniquiz/presentation/backup/backup_panel.dart';

class FakeBackupActions implements BackupActions {
  int exports = 0, restores = 0;
  @override
  Future<int?> export() async {
    exports++;
    return 0;
  }

  @override
  Future<int?> restore() async {
    restores++;
    return 2;
  }
}

void main() {
  testWidgets(
    'backup controls show results and require confirmation before additive restore',
    (tester) async {
      final actions = FakeBackupActions();
      var maintenance = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BackupPanel(
              actions: actions,
              runExclusive: (work) async {
                maintenance++;
                await work();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();
      expect(actions.exports, 1);
      expect(find.text('Backup saved.'), findsOneWidget);
      await tester.tap(find.text('Restore backup'));
      await tester.pumpAndSettle();
      expect(actions.restores, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Restore backup'));
      await tester.pumpAndSettle();
      expect(actions.restores, 1);
      expect(maintenance, 2);
      expect(
        find.text('Restored 2 libraries. Switch libraries to open them.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
