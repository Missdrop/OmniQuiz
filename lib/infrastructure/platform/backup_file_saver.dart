// Delegates archive export to native document providers instead of loading a second byte copy.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Mobile document providers receive a file path, not a 100 MB method payload.
class BackupFileSaver {
  BackupFileSaver({TargetPlatform? platform})
    : platform = platform ?? defaultTargetPlatform;
  final TargetPlatform platform;
  static const channel = MethodChannel('io.github.missdrop.omniquiz/backup');

  Future<bool> save(File file) async {
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return await channel.invokeMethod<bool>('exportBackup', {
            'path': file.path,
          }) ??
          false;
    }
    return await FilePicker.saveFile(
          fileName: 'OmniQuiz-backup.zip',
          mimeType: 'application/zip',
          bytes: await file.readAsBytes(),
        ) !=
        null;
  }
}
