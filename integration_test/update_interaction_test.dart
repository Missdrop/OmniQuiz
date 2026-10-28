// Native update-control and permission audit; installation transitions use fake release services.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/updates/update_installer.dart';
import 'package:omniquiz/main.dart' as app;
import 'package:omniquiz/presentation/updates/update_controller.dart';
import 'package:omniquiz/presentation/updates/update_panel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../test/ai_test.dart' show MemoryCredentials;
import '../test/coordinator_test.dart' show FakeGenerator;
import '../test/update_test.dart'
    show FixtureUpdater, FixtureInstaller, MemoryUpdatePreferences;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var converted = false;
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.isAndroid && !converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
      addTearDown(() => converted = false);
    }
    await tester.pump();
    final directory = await Directory(
      '${(await getApplicationDocumentsDirectory()).path}/update-audit',
    ).create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(await binding.takeScreenshot(name));
  }

  testWidgets('native version information and actual app update controls', (
    tester,
  ) async {
    final info = await PackageInfo.fromPlatform();
    expect(info.version, isNotEmpty);
    await app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    final panel = find.byType(UpdatePanel);
    await tester.ensureVisible(panel);
    await capture(tester, '01-native-update-settings');
    expect(panel, findsOneWidget);
    final installer = UpdateInstaller();
    if (Platform.isAndroid) {
      expect(await installer.androidAbis(), isNotEmpty);
      await expectLater(
        installer.install(File('/sdcard/not-an-update.apk')),
        throwsA(anything),
      );
    } else if (Platform.isIOS) {
      expect(await installer.platform(), 'ios');
    }
  });

  testWidgets(
    'native optional update notice, skip, manual recheck and user-initiated update',
    (tester) async {
      final service = FixtureUpdater();
      final installer = FixtureInstaller();
      final prefs = MemoryUpdatePreferences();
      final controller = UpdateController(
        prefs,
        service: service,
        installer: installer,
      );
      final deps = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        credentialStore: MemoryCredentials(),
        ai: FakeGenerator(),
      );
      await deps.language.select('en');
      runApp(OmniQuizApp(dependencies: deps, updates: controller));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(service.downloads, 0);
      await capture(tester, '02-optional-update');
      await tester.ensureVisible(find.text('Skip this version'));
      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();
      expect(prefs.value['skippedVersion'], '1.1.0');
      expect(service.downloads, 0);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check for updates'));
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);
      await tester.ensureVisible(find.text('Remind me later'));
      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
      expect(installer.installs, 0);
      await tester.ensureVisible(find.text('View update'));
      await tester.tap(find.text('View update'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Update now'));
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(service.downloads, 1);
      expect(
        installer.installs,
        1,
      ); // Fixture avoids replacing the running test app.
      await capture(tester, '03-verified-ready');
      if (Platform.isIOS) {
        await tester.ensureVisible(find.text('Remind me later'));
        await tester.tap(find.text('Remind me later'));
        await tester.pumpAndSettle();
        installer.target = 'ios';
        await controller.check();
        await tester.pumpAndSettle();
        expect(controller.asset, isNull);
        expect(find.text('Update now'), findsNothing);
        expect(find.text('Official download page'), findsWidgets);
        await capture(tester, '04-ios-official-fallback');
      }
      runApp(const SizedBox());
      await tester.pumpAndSettle();
      controller.dispose();
      await deps.dispose();
    },
  );

  if (Platform.isAndroid &&
      const bool.fromEnvironment('RUN_NATIVE_UPDATE_INSTALL')) {
    testWidgets(
      'Android hands a newer matching-signature APK to the system installer',
      (tester) async {
        final file = File(
          '${(await getTemporaryDirectory()).path}/updates/test/next.apk',
        );
        expect(await file.exists(), true);
        var result = await UpdateInstaller.channel.invokeMethod<String>(
          'install',
          {'path': file.path},
        );
        if (result == 'permission') {
          debugPrint('UPDATE_AUDIT_PERMISSION');
          // The host test operator enables the visible system permission toggle.
          await Future<void>.delayed(const Duration(seconds: 15));
          result = await UpdateInstaller.channel.invokeMethod<String>(
            'install',
            {'path': file.path},
          );
        }
        expect(result, 'installer');
        debugPrint('UPDATE_AUDIT_INSTALLER');
      },
    );
  }
}
