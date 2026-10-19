import 'dart:io';

import 'package:flutter/services.dart';

/// macOS sandbox grants must outlive the file-picker dialog and app process.
class FolderPermissions {
  static const _channel = MethodChannel('omniquiz/folders');
  static Future<void> remember(String directory) async {
    if (Platform.isMacOS) {
      await _channel.invokeMethod<void>('remember', directory);
    }
  }

  static Future<void> restore(String directory) async {
    if (Platform.isMacOS) {
      await _channel.invokeMethod<void>('restore', directory);
    }
  }
}
