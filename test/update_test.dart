// Opt-in update notices, skips, downloads, digest checks and installer transitions with fake services.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omniquiz/app/theme.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/updates/release_updater.dart';
import 'package:omniquiz/infrastructure/updates/update_installer.dart';
import 'package:omniquiz/infrastructure/updates/update_preferences.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/updates/update_controller.dart';
import 'package:omniquiz/presentation/updates/update_panel.dart';
import 'package:pub_semver/pub_semver.dart';

const bytes = [1, 2, 3, 4];
const assetName = 'OmniQuiz-windows-x64.msi';
Uri assetUrl(String name) => Uri.parse(
  'https://github.com/Missdrop/OmniQuiz/releases/download/v1.1.0/$name',
);
Map<String, dynamic> releaseJson({String tag = 'v1.1.0'}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'Fixes and improvements',
  'assets': [
    {
      'name': assetName,
      'browser_download_url': assetUrl(assetName).toString(),
      'size': bytes.length,
      'digest': 'sha256:${sha256.convert(bytes)}',
    },
  ],
};
AppRelease releaseFixture({String version = '1.1.0'}) =>
    AppRelease(Version.parse(version), 'v$version', 'Fixes and improvements', [
      UpdateAsset(
        assetName,
        assetUrl(assetName),
        bytes.length,
        'sha256:${sha256.convert(bytes)}',
      ),
    ]);

class MemoryUpdatePreferences implements UpdatePreferences {
  Map<String, dynamic> value = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> load() async => {...value};
  @override
  Future<void> save(Map<String, dynamic> value) async {
    if (fail) throw const FileSystemException('read only');
    this.value = {...value};
  }
}

class FixtureUpdater extends ReleaseUpdater {
  AppRelease? next = releaseFixture();
  int checks = 0, downloads = 0;
  bool failDownload = false;
  Completer<void>? gate;
  @override
  Future<AppRelease?> latest() async {
    checks++;
    return next;
  }

  @override
  Future<File> download(
    AppRelease release,
    UpdateAsset asset,
    Directory cache,
    void Function(int, int) progress,
  ) async {
    downloads++;
    await gate?.future;
    if (failDownload) throw const FormatException();
    progress(4, 4);
    return File('fixture.msi');
  }
}

class FixtureInstaller extends UpdateInstaller {
  int installs = 0;
  String target = 'windows-x64';
  @override
  Future<String> platform() async => target;
  @override
  Future<bool> install(
    File file, {
    Future<void> Function()? prepareToExit,
  }) async {
    installs++;
    return true;
  }
}

void main() {
  testWidgets('closing an in-progress update notice postpones installation', (
    tester,
  ) async {
    final service = FixtureUpdater()..gate = Completer<void>();
    final installer = FixtureInstaller();
    final controller = UpdateController(
      MemoryUpdatePreferences(),
      service: service,
      installer: installer,
      versionReader: () async => '1.0.0',
      cacheDirectory: () async => Directory.systemTemp,
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: UpdatePanel(controller: controller)),
      ),
    );
    await tester.tap(find.text('View update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(controller.status, UpdateStatus.downloading);
    await tester.tap(find.text('Remind me later'));
    await tester.pumpAndSettle();
    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(controller.status, UpdateStatus.ready);
    expect(installer.installs, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  test('only stable official release metadata is accepted, including no stable release yet', () async {
    final valid = await ReleaseUpdater(
      clientFactory: () => MockClient(
        (_) async => http.Response(jsonEncode(releaseJson()), 200),
      ),
    ).latest();
    expect(valid!.version, Version(1, 1, 0));
    expect(valid.website.host, 'github.com');
    expect(
      await ReleaseUpdater(
        clientFactory: () => MockClient((_) async => http.Response('', 404)),
      ).latest(),
      isNull,
    );
    for (final json in [
      releaseJson()..['prerelease'] = true,
      releaseJson(tag: 'nightly'),
      releaseJson(tag: 'v1.1.0-beta.1'),
    ]) {
      await expectLater(
        ReleaseUpdater(
          clientFactory: () =>
              MockClient((_) async => http.Response(jsonEncode(json), 200)),
        ).latest(),
        throwsFormatException,
      );
    }
    final json = releaseJson();
    (json['assets'] as List).first['browser_download_url'] =
        'https://example.com/update.msi';
    final unsafe = await ReleaseUpdater(
      clientFactory: () =>
          MockClient((_) async => http.Response(jsonEncode(json), 200)),
    ).latest();
    expect(unsafe!.assets, isEmpty);
  });

  test('checks never download; skip survives restart and manual checks can override it', () async {
    final prefs = MemoryUpdatePreferences();
    final service = FixtureUpdater();
    final installer = FixtureInstaller();
    UpdateController create() => UpdateController(
      prefs,
      service: service,
      installer: installer,
      versionReader: () async => '1.0.0',
      cacheDirectory: () async => Directory.systemTemp,
    );
    var controller = create();
    await controller.initialize();
    expect(controller.notification, 1);
    expect(service.downloads, 0);
    expect(installer.installs, 0);
    await controller.skip();
    controller.dispose();
    controller = create();
    await controller.initialize();
    expect(controller.notification, 0);
    expect(controller.status, UpdateStatus.available);
    await controller.check();
    expect(controller.notification, 1);
    await controller.setAutoCheck(false);
    controller.dispose();
    final checks = service.checks;
    controller = create();
    await controller.initialize();
    expect(service.checks, checks);
    await controller.check();
    expect(service.checks, checks + 1);
    service.next = releaseFixture(version: '1.10.0');
    await controller.check(manual: false);
    expect(controller.release!.version > Version(1, 2, 0), true);
    expect(service.downloads, 0);
    controller.dispose();
  });

  test('preference write failure preserves the old setting and does not mark a version skipped', () async {
    final prefs = MemoryUpdatePreferences()..fail = true;
    final controller = UpdateController(
      prefs,
      service: FixtureUpdater(),
      installer: FixtureInstaller(),
      versionReader: () async => '1.0.0',
      cacheDirectory: () async => Directory.systemTemp,
    );
    await controller.initialize();
    await controller.setAutoCheck(false);
    expect(controller.autoCheck, true);
    await controller.skip();
    expect(controller.skippedVersion, isNull);
    expect(controller.saveFailed, true);
    controller.dispose();
  });

  test('update preferences do not invalidate generation and are shared by a database reopen', () async {
    final root = await Directory.systemTemp.createTemp('omniquiz-update-db-');
    final dbFile = File('${root.path}/test.sqlite');
    var db = QuizDatabase(NativeDatabase(dbFile));
    await SqlUpdatePreferences(db)
        .save({'autoCheck': false, 'skippedVersion': '1.1.0'});
    expect(
      (await db
              .customSelect("SELECT value FROM settings WHERE key='epoch'")
              .getSingle())
          .read<String>('value'),
      '0',
    );
    await db.close();
    db = QuizDatabase(NativeDatabase(dbFile));
    expect(await SqlUpdatePreferences(db).load(), {
      'autoCheck': false,
      'skippedVersion': '1.1.0',
    });
    await db.close();
    await root.delete(recursive: true);
  });

  test('compatible platform assets use native Android ABI order and never offer unsigned iOS', () {
    final release = AppRelease(Version(1, 1, 0), 'v1.1.0', '', [
      for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64'])
        UpdateAsset(
          'OmniQuiz-android-$abi.apk',
          assetUrl('OmniQuiz-android-$abi.apk'),
          4,
          null,
        ),
    ]);
    expect(
      ReleaseUpdater.assetFor(
        release,
        'android',
        abis: ['x86_64', 'arm64-v8a'],
      )!.name,
      contains('x86_64'),
    );
    expect(
      ReleaseUpdater.assetFor(release, 'android', abis: ['unsupported']),
      isNull,
    );
    expect(ReleaseUpdater.assetFor(release, 'ios'), isNull);
  });

  test('downloads stream to a verified file and accept the published checksum fallback', () async {
    final root = await Directory.systemTemp.createTemp('omniquiz-download-');
    try {
      for (final useDigest in [true, false]) {
        final release = releaseFixture();
        final asset = UpdateAsset(
          assetName,
          assetUrl(assetName),
          4,
          useDigest ? 'sha256:${sha256.convert(bytes)}' : null,
        );
        final withSums = AppRelease(release.version, release.tag, '', [
          asset,
          UpdateAsset('SHA256SUMS', assetUrl('SHA256SUMS'), 100, null),
        ]);
        final service = ReleaseUpdater(
          clientFactory: () => MockClient(
            (request) async => request.url.path.endsWith('SHA256SUMS')
                ? http.Response('${sha256.convert(bytes)}  $assetName\n', 200)
                : http.Response.bytes(bytes, 200),
          ),
        );
        final file = await service.download(withSums, asset, root, (_, _) {});
        expect(await file.readAsBytes(), bytes);
        expect(file.path.endsWith('.part'), false);
      }
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'hash, size, redirect and cancellation failures remove partial downloads',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'omniquiz-bad-download-',
      );
      final release = releaseFixture();
      for (final mode in ['hash', 'size', 'redirect', 'cancel']) {
        late ReleaseUpdater service;
        service = ReleaseUpdater(
          clientFactory: () => MockClient((_) async {
            if (mode == 'redirect') {
              return http.Response(
                '',
                302,
                headers: {'location': 'https://example.com/malware'},
              );
            }
            return http.Response.bytes(
              mode == 'size'
                  ? [1]
                  : mode == 'hash'
                  ? [9, 9, 9, 9]
                  : bytes,
              200,
            );
          }),
        );
        await expectLater(
          service.download(release, release.assets.first, root, (_, _) {
            if (mode == 'cancel') service.cancel();
          }),
          throwsFormatException,
        );
        expect(await root.list().toList(), isEmpty, reason: mode);
      }
      await root.delete(recursive: true);
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets(
      '$language update UI remains optional on a small phone and downloads only on tap',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = MemoryUpdatePreferences();
        final service = FixtureUpdater();
        final installer = FixtureInstaller();
        final controller = UpdateController(
          prefs,
          service: service,
          installer: installer,
          versionReader: () async => '1.0.0',
          cacheDirectory: () async => Directory.systemTemp,
        );
        await controller.initialize();
        addTearDown(controller.dispose);
        final l = await AppLocalizations.delegate.load(Locale(language));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: UpdatePanel(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(service.downloads, 0);
        await tester.ensureVisible(find.text(l.updateDetails));
        await tester.tap(find.text(l.updateDetails));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.updateLater));
        await tester.tap(find.text(l.updateLater));
        await tester.pumpAndSettle();
        expect(service.downloads, 0);
        expect(find.byType(UpdateDialog), findsNothing);
        await tester.tap(find.text(l.updateDetails));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.updateSkip));
        await tester.tap(find.text(l.updateSkip));
        await tester.pumpAndSettle();
        expect(controller.skippedVersion, '1.1.0');
        expect(service.downloads, 0);
        await tester.tap(find.text(l.updateDetails));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.updateNow));
        await tester.tap(find.text(l.updateNow));
        await tester.pumpAndSettle();
        expect(service.downloads, 1);
        expect(installer.installs, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
