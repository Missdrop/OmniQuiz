// Desktop staging and replacement helpers preserve a restartable app when installation is cancelled or fails.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/infrastructure/updates/update_installer.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Windows helper restarts the installed app on success and the old app on cancellation', () async {
    final root = await Directory.systemTemp.createTemp(
      "omniquiz windows update's ",
    );
    final temporary = await Directory.systemTemp.resolveSymbolicLinks();
    expect(p.isWithin(temporary, await root.resolveSymbolicLinks()), true);
    try {
      final source = File(p.join(root.path, 'Fixture.cs'));
      await source.writeAsString(
        '''using System; using System.IO; using System.Reflection;
class Fixture { static int Main(string[] args) {
  if (args.Length >= 2) return int.Parse(File.ReadAllText(args[1]));
  File.WriteAllText(Assembly.GetExecutingAssembly().Location + ".started", "ok");
  return 0;
} }''',
      );
      final compiler = p.join(
        Platform.environment['SystemRoot']!,
        'Microsoft.NET',
        'Framework64',
        'v4.0.30319',
        'csc.exe',
      );
      final installer = p.join(root.path, 'installer.exe');
      expect(
        (await Process.run(compiler, [
          '/nologo',
          '/target:winexe',
          '/out:$installer',
          source.path,
        ])).exitCode,
        0,
      );
      final helper = File(p.join(root.path, 'finish-update.ps1'));
      await helper.writeAsString(UpdateInstaller.windowsHelper);
      for (final code in [0, 1602, 3010]) {
        final installed = await File(installer)
            .copy(p.join(root.path, 'new-$code.exe'));
        final previous = await File(installer)
            .copy(p.join(root.path, 'old-$code.exe'));
        final msi = File(p.join(root.path, 'update-$code.msi'));
        await msi.writeAsString('$code');
        final result = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          helper.path,
          msi.path,
          installed.path,
          previous.path,
          installer,
        ]);
        expect(result.exitCode, 0);
        final marker = File(
          '${code == 1602 ? previous.path : installed.path}.started',
        );
        for (
          var attempt = 0;
          attempt < 100 && !await marker.exists();
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await marker.exists(), true, reason: 'installer exit $code');
        expect(
          await File('${code == 1602 ? installed.path : previous.path}.started')
              .exists(),
          false,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
  test(
    'macOS verifies and stages a real DMG before touching the installed bundle',
    () async {
      final dmg = File(Platform.environment['OMNIQUIZ_TEST_DMG']!);
      final root = await Directory.systemTemp.createTemp(
        'omniquiz-macos-stage-',
      );
      try {
        final source = p.join(
          Directory.current.path,
          'build',
          'macos',
          'Build',
          'Products',
          'Release',
          'OmniQuiz.app',
        );
        final current = p.join(root.path, 'OmniQuiz.app');
        expect(
          (await Process.run('/usr/bin/ditto', [source, current])).exitCode,
          0,
        );
        final marker = File(
          p.join(current, 'Contents', 'Resources', 'old-marker'),
        );
        await marker.writeAsString('old app stays intact');
        final stage = await UpdateInstaller.stageDesktop(
          dmg,
          p.join(current, 'Contents', 'MacOS', 'OmniQuiz'),
          macos: true,
        );
        expect(
          (await Process.run('/usr/bin/codesign', [
            '--verify',
            '--deep',
            '--strict',
            stage.replacement,
          ])).exitCode,
          0,
        );
        expect(await marker.readAsString(), 'old app stays intact');
        expect(
          await File(
            p.join(stage.replacement, 'Contents', 'Resources', 'old-marker'),
          ).exists(),
          false,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip:
        !Platform.isMacOS || Platform.environment['OMNIQUIZ_TEST_DMG'] == null,
  );
  for (final rollback in [false, true]) {
    test(
      'desktop helper ${rollback ? 'rolls back a failed swap' : 'replaces and restarts the bundle'} without changing app data',
      () async {
        final root = await Directory.systemTemp.createTemp(
          "omniquiz update's ",
        );
        try {
          final target = await Directory(p.join(root.path, 'installed app'))
              .create();
          final staging = await Directory(p.join(root.path, '.staging'))
              .create();
          final replacement = Directory(p.join(staging.path, 'replacement'));
          final backup = p.join(staging.path, 'previous');
          final userData = File(p.join(root.path, 'user-data.sqlite'));
          await userData.writeAsString('learning progress');
          Future<void> executable(Directory directory, String marker) async {
            await directory.create(recursive: true);
            final binary = File(p.join(directory.path, 'omniquiz'));
            await binary.writeAsString(
              '#!/bin/sh\nprintf $marker > "\$(dirname "\$0")/restarted"\n',
            );
            expect(
              (await Process.run('chmod', ['+x', binary.path])).exitCode,
              0,
            );
          }

          await executable(target, 'old');
          if (!rollback) await executable(replacement, 'new');
          final helper = File(p.join(root.path, 'update.sh'));
          await helper.writeAsString(UpdateInstaller.desktopHelper);
          final result = await Process.run('/bin/bash', [
            helper.path,
            '99999999',
            target.path,
            replacement.path,
            backup,
            'linux',
          ]);
          expect(result.exitCode, rollback ? 1 : 0);
          final marker = File(p.join(target.path, 'restarted'));
          for (var i = 0; i < 40 && !await marker.exists(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          expect(await marker.readAsString(), rollback ? 'old' : 'new');
          expect(await userData.readAsString(), 'learning progress');
          if (!rollback) {
            expect(await File(p.join(backup, 'omniquiz')).exists(), true);
          }
        } finally {
          await root.delete(recursive: true);
        }
      },
      skip: !(Platform.isLinux || Platform.isMacOS),
    );
  }

  test(
    'Linux updater stages a complete bundle beside the existing app',
    () async {
      final root = await Directory.systemTemp.createTemp('omniquiz-stage-');
      try {
        final current = await Directory(p.join(root.path, 'current')).create();
        await Directory(p.join(current.path, 'data', 'flutter_assets'))
            .create(recursive: true);
        await Directory(p.join(current.path, 'lib')).create();
        await File(p.join(current.path, 'lib', 'libflutter_linux_gtk.so'))
            .writeAsString('old library');
        final payload = await Directory(
          p.join(root.path, 'payload', 'OmniQuiz'),
        ).create(recursive: true);
        await File(p.join(payload.path, 'omniquiz'))
            .writeAsString('new executable');
        final archive = File(p.join(root.path, 'update.tar.gz'));
        expect(
          (await Process.run('/usr/bin/tar', [
            '-czf',
            archive.path,
            '-C',
            payload.parent.path,
            'OmniQuiz',
          ])).exitCode,
          0,
        );
        final stage = await UpdateInstaller.stageDesktop(
          archive,
          p.join(current.path, 'omniquiz'),
          macos: false,
        );
        expect(stage.target, current.path);
        expect(
          await File(p.join(stage.replacement, 'omniquiz')).readAsString(),
          'new executable',
        );
        expect(
          await File(p.join(current.path, 'lib', 'libflutter_linux_gtk.so'))
              .readAsString(),
          'old library',
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: !Platform.isLinux,
  );
}
