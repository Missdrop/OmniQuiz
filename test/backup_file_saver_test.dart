// Native archive-export channel arguments and cancellation without copying archive bytes through widgets.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/infrastructure/platform/backup_file_saver.dart';

/// Fails if the mobile saver attempts to read the archive into Dart memory.
class PathOnlyFile implements File {
  @override
  String get path => '/temporary/OmniQuiz-backup.zip';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected file access: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(BackupFileSaver.channel, null),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform exports only a path and waits for native completion',
      () async {
        messenger.setMockMethodCallHandler(BackupFileSaver.channel, (
          call,
        ) async {
          expect(call.method, 'exportBackup');
          expect(call.arguments, {'path': PathOnlyFile().path});
          return true;
        });
        expect(
          await BackupFileSaver(platform: platform).save(PathOnlyFile()),
          true,
        );
      },
    );
  }

  test('cancelled export is distinct from a platform write failure', () async {
    final saver = BackupFileSaver(platform: TargetPlatform.android);
    messenger.setMockMethodCallHandler(
      BackupFileSaver.channel,
      (_) async => null,
    );
    expect(await saver.save(PathOnlyFile()), false);
    messenger.setMockMethodCallHandler(BackupFileSaver.channel, (_) async {
      throw PlatformException(code: 'export_failed');
    });
    await expectLater(
      saver.save(PathOnlyFile()),
      throwsA(isA<PlatformException>()),
    );
  });
}
